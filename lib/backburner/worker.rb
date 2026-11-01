require 'backburner/job'

module Backburner
  #
  # @abstract Subclass and override {#process_tube_names}, {#prepare} and {#start} to implement
  #   a custom Worker class.
  #
  class Worker
    include Backburner::Helpers
    include Backburner::Logger

    # The longest a worker that doesn't have a job's class waits to hand the job out again (its TTR
    # otherwise), so a worker that has it picks it up soon after a rollout
    MAX_CLASS_NOT_FOUND_DELAY = 60

    # Backburner::Worker.known_queue_classes
    # List of known_queue_classes
    class << self
      attr_writer :known_queue_classes
      def known_queue_classes; @known_queue_classes ||= []; end
    end

    # Enqueues a job to be processed later by a worker.
    # Options: `pri` (priority), `delay` (delay in secs, rounded up to whole seconds), `ttr` (time to respond),
    # `queue` (queue name)
    #
    # @raise [Beaneater::NotConnected] If beanstalk fails to connect.
    # @example
    #   Backburner::Worker.enqueue NewsletterSender, [self.id, user.id], :ttr => 1000
    #
    def self.enqueue(job_class, args=[], opts={})
      pri   = resolve_priority(opts[:pri] || job_class)
      delay = whole_seconds(opts[:delay])
      ttr   = resolve_respond_timeout(opts[:ttr] || job_class)
      res   = Backburner::Hooks.invoke_hook_events(job_class, :before_enqueue, *args)

      return nil unless res # stop if hook is false

      data = { :class => job_class.name, :args => args }
      queue = opts[:queue] && (Proc === opts[:queue] ? opts[:queue].call(job_class) : opts[:queue])

      response = nil
      Backburner::EnqueuePool.current.with_connection do |connection|
        connection.retryable do
          tube = connection.tubes[expand_tube_name(queue || job_class)]
          serialized_data = Backburner.configuration.job_serializer_proc.call(data)
          response = tube.put(serialized_data, :pri => pri, :delay => delay, :ttr => ttr)
        end
      end
      return nil unless Backburner::Hooks.invoke_hook_events(job_class, :after_enqueue, *args)

      response
    end

    # Starts processing jobs with the specified tube_names.
    #
    # @example
    #   Backburner::Worker.start(["foo.tube.name"])
    #
    def self.start(tube_names=nil)
      begin
        self.new(tube_names).start
      rescue SystemExit
        # do nothing
      end
    end

    # List of tube names to be watched and processed
    attr_accessor :tube_names, :connection

    # Constructs a new worker for processing jobs within specified tubes.
    #
    # @example
    #   Worker.new(['test.job'])
    def initialize(tube_names=nil)
      @existing_tube_names = nil # set by all_existing_queues, read by expand_tube_name
      @connection = new_connection
      @tube_names = self.process_tube_names(tube_names)
      register_signal_handlers!
    end

    # Starts processing ready jobs indefinitely.
    # Primary way to consume and process jobs in specified tubes.
    #
    # @example
    #   @worker.start
    #
    def start
      raise NotImplementedError
    end

    # Used to prepare the job queues before job processing is initiated.
    #
    # @raise [Beaneater::NotConnected] If beanstalk fails to connect.
    # @example
    #   @worker.prepare
    #
    # @abstract Define this in your worker subclass
    # to be run once before processing. Recommended to watch tubes
    # or print a message to the logs with 'log_info'
    #
    def prepare
      raise NotImplementedError
    end

    # Triggers this worker to shutdown
    def shutdown
      # Logs from another thread, since a trap handler can't take a logger's lock, and waits for it (a
      # second at most): the process exits right after, and an unjoined thread never got to run
      Thread.new { log_info 'Worker exiting...' }.join(1)
    ensure
      Kernel.exit
    end

    # Processes tube_names given tube_names array.
    # Should return normalized tube_names as an array of strings.
    #
    # @example
    #   process_tube_names([['foo'], ['bar']])
    #   => ['foo', 'bar', 'baz']
    #
    # @note This method can be overridden in inherited workers
    # to add more complex tube name processing.
    def process_tube_names(tube_names)
      compact_tube_names(tube_names)
    end

    # Performs a job by reserving a job from beanstalk and processing it
    #
    # @example
    #   @worker.work_one_job
    # @raise [Beaneater::NotConnected] If beanstalk fails to connect multiple times.
    def work_one_job(conn = connection)
      begin
        job = reserve_job(conn)
      rescue Beaneater::TimedOutError => e
        return
      end

      self.log_job_begin(job.name, job.args)
      wrap_in_rails_reloader { job.process }
      self.log_job_end(job.name)

    rescue Backburner::Job::JobFormatInvalid => e
      self.log_error self.exception_message(e)
    rescue => e # Error occurred processing job
      self.log_error self.exception_message(e) unless e.is_a?(Backburner::Job::RetryJob)

      unless job
        self.log_error "Error occurred before we were able to assign a job. Giving up without retrying!"
        return
      end

      # NB: There's a slight chance here that the connection to beanstalkd has
      # gone down between the time we reserved / processed the job and here.
      class_missing = false
      begin
        job_class = begin
          job.job_class
        rescue Backburner::Job::JobNotFound # missing, or its file failed to load: see below
          nil
        end
        if job_class.nil? && job.job_class_missing?
          # This worker doesn't have its class (renamed or removed, or a worker deployed before the code
          # that enqueues it): give it back for a worker that has it rather than burying it, once per TTR
          # (at most a minute) as beanstalkd would, without on_error or the failure hooks (as before) or
          # using up its retries. A class whose file fails to load goes the normal failure path instead.
          # ceiling: beanstalkd still counts the release, so once a worker has the class, a failure there
          # gets fewer retries; counting these releases apart would need a marker in the job body.
          class_missing = true
          delay = [job.ttr || queue_config.respond_timeout, MAX_CLASS_NOT_FOUND_DELAY].min
          job.task.release(:delay => delay)
          self.log_warn "#{job.name}: class not found; released for #{delay}s for a worker that has it"
          return
        end
        num_retries = job.stats.releases
        max_job_retries = resolve_max_job_retries(job_class)
        retry_status = "failed: attempt #{num_retries+1} of #{max_job_retries+1}"
        if num_retries < max_job_retries # retry again
          retry_delay = resolve_retry_delay(job_class)
          delay = resolve_retry_delay_proc(job_class).call(retry_delay, num_retries) rescue retry_delay
          delay = whole_seconds(delay)
          job.retry(num_retries + 1, delay)
          self.log_job_end(job.name, "#{retry_status}, retrying in #{delay}s") if job_started_at
        else # retries failed, bury
          job.bury
          self.log_job_end(job.name, "#{retry_status}, burying") if job_started_at
        end
      rescue Beaneater::NotFoundError, Beaneater::NotConnected
        # Its TTR ran out first, or the connection was lost: beanstalkd releases a reserved job when
        # its TTR runs out or its client disconnects (unless the server restarted and lost it).
        # (An error raised in a rescue clause isn't caught by the method's other rescues, hence this one.)
        self.log_error "#{job.name} was no longer reserved (its TTR ran out, or the connection was lost), so it was neither retried nor buried"
        return if class_missing # on_error isn't called for a class this worker lacks
      end

      handle_error(e, job.name, job.args, job)
    end


    protected

    # Return a new connection instance
    def new_connection
      Connection.new(Backburner.configuration.beanstalk_url) { |conn| Backburner::Hooks.invoke_hook_events(self, :on_reconnect, conn) }
    end

    # Runs the block (a job's processing) in the Rails app's reloader when there is one, as Rails does for Active Job
    # jobs (whose own wrap, inside this one, then does nothing): each job starts with fresh CurrentAttributes, gives
    # back its database connections when it's done and, in development, runs the app's latest code. On Rails 7.0+ the
    # wrap reports the errors that leave it to Rails.error (with the source "job.backburner" on 7.1+); a RetryJob, a
    # request to retry rather than a failure, is raised again outside it instead.
    # ceiling: config.on_error and the on_retry and on_bury hooks run after the wrap ends, so they don't see the job's
    # CurrentAttributes, and a database connection they use is outside the executor; running work_one_job's failure
    # handling inside the wrap would lift it.
    def wrap_in_rails_reloader
      app = ::Rails.application if defined?(::Rails) && ::Rails.respond_to?(:application)
      return yield unless app.respond_to?(:reloader)
      retry_job = nil
      work = proc do
        begin
          yield
        rescue Backburner::Job::RetryJob => e
          retry_job = e
        end
      end
      # Rails 7.1+ take the source the executor reports errors with; older ones take no options
      if app.reloader.method(:wrap).parameters.any? { |type, name| type == :keyrest || name == :source }
        app.reloader.wrap(source: "job.backburner", &work)
      else
        app.reloader.wrap(&work)
      end
      raise retry_job if retry_job
    end

    # Reserve a job from the watched queues
    def reserve_job(conn, reserve_timeout = Backburner.configuration.reserve_timeout)
      Backburner::Job.new(conn.tubes.reserve(reserve_timeout))
    end

    # Returns a list of all tubes known within the system
    # Filtered for tubes that match the known prefix
    def all_existing_queues
      known_queues    = Backburner::Worker.known_queue_classes.select(&:name).map(&:queue) # an anonymous class can't be a job
      prefix          = expanded_tube_prefix # the start of every tube name enqueueing with this configuration gives
      namespace       = queue_config.tube_namespace
      cut             = namespace && "#{namespace}#{queue_config.namespace_separator}".include?(':') # every name is the prefix
      existing_tubes  = self.connection.tubes.all.map(&:name).select do |tube| # only the names this configuration can give
        cut ? tube == prefix : tube.start_with?(prefix) && tube[prefix.size..-1] !~ /[A-Z_]/ # the rest is dasherized
      end
      # ceiling: a server tube named exactly like a known queue name is still expanded like that name, as before;
      # the workers' prepare keeping found tubes apart from queue names would lift it
      @existing_tube_names = existing_tubes - known_queues - [queue_config.primary_queue]
      existing_tubes + known_queues + [queue_config.primary_queue]
    end

    # Leaves the server's tube names all_existing_queues found as they are: expanding one again can change it
    # ("MyApp.default" would become "MyApp.my-app.default")
    def expand_tube_name(tube)
      @existing_tube_names && @existing_tube_names.include?(tube) ? tube : super
    end
    public :expand_tube_name


    # Merges the options the block gives for each known queue class (its queue_jobs_limit and so on)
    # into its tube's entry in tubes_data, for tubes that are there. A class that declares its tube
    # overrides the tube's options; a subclass sharing its parent's tube only fills in the ones still
    # unset. Anonymous classes are skipped.
    def merge_tube_settings(tubes_data)
      owners, sharers = Backburner::Worker.known_queue_classes.select(&:name).partition { |queue| !shares_parent_tube?(queue) }
      [[owners, true], [sharers, false]].each do |classes, override|
        classes.each do |queue|
          data = tubes_data[expand_tube_name(queue)]
          next if data.nil?
          data.merge!(yield(queue)) { |_key, current, setting| (override ? setting.nil? : !current.nil?) ? current : setting }
        end
      end
    end

    # Whether a queue class uses the same tube as its closest named Backburner::Queue ancestor
    def shares_parent_tube?(queue)
      return false unless queue.respond_to?(:superclass)
      parent = queue.superclass
      parent = parent.superclass while parent.is_a?(Backburner::Queue::ClassMethods) && parent.name.nil?
      parent.is_a?(Backburner::Queue::ClassMethods) && expand_tube_name(parent) == expand_tube_name(queue)
    end

    # Handles an error according to custom definition
    # Used when processing a job that errors out
    def handle_error(e, name, args, job)
      if error_handler = Backburner.configuration.on_error
        if error_handler.arity == 1
          error_handler.call(e)
        elsif error_handler.arity == 3
          error_handler.call(e, name, args)
        else
          error_handler.call(e, name, args, job)
        end
      end
    rescue => handler_error # an error reporter that fails (can't reach its service, say) mustn't stop the worker
      log_error "The on_error handler failed for #{name}: #{exception_message(handler_error)}"
    end

    # Normalizes tube names given array of tube_names
    # Compacts nil items, flattens arrays, sets tubes to nil if no valid names
    # Loads default tubes when no tubes given.
    def compact_tube_names(tube_names)
      tube_names = tube_names.first if tube_names && tube_names.size == 1 && tube_names.first.is_a?(Array)
      tube_names = Array(tube_names).compact if tube_names && Array(tube_names).compact.size > 0
      tube_names = nil if tube_names && tube_names.compact.empty?
      tube_names ||= Backburner.default_queues.any? ? Backburner.default_queues : all_existing_queues
      Array(tube_names).uniq
    end

    # Registers signal handlers TERM and INT to trigger
    def register_signal_handlers!
      trap('TERM') { shutdown  }
      trap('INT')  { shutdown  }
    end

    # Whether a forked child disables the GC as it exits (see with_gc_disabled_on_exit): only on CRuby 3.3
    def self.gc_disabled_on_exit?(engine = RUBY_ENGINE, version = RUBY_VERSION)
      engine == "ruby" && version.start_with?("3.3.")
    end

    # Runs the body of a forked child, then, on Ruby 3.3, disables the GC before the child exits by any
    # path that tears the interpreter down: returning, an exception, or Kernel.exit (as the TERM and INT
    # traps do). Kernel.exit! skips the ensure, and the teardown with it. The child's at_exit handlers
    # (its own and those it inherited) then run with the GC off.
    # ceiling: works around a Ruby 3.3 bug: a child forked while another thread of its parent runs
    # finalizers can crash as it exits ("[BUG] lazy sweeping underway when freeing object space").
    # GC.disable finishes the lazy sweep first. Fixed in Ruby 3.4 by ruby/ruby 868d63f0a3 (not
    # backported to 3.3, and not seen on 3.1 or 3.2); this can go once Ruby 3.3 support is dropped.
    # Limits: an at_exit handler that calls GC.enable itself can still crash, and a TERM that lands while
    # a ThreadsOnFork child is starting its job threads can leave one of them running during at_exit.
    def with_gc_disabled_on_exit
      yield
    ensure
      GC.disable if Worker.gc_disabled_on_exit?
    end
  end # Worker
end # Backburner
