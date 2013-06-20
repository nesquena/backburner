require 'backburner/job'

module Backburner
  #
  # @abstract Subclass and override {#process_tube_names}, {#prepare} and {#start} to implement
  #   a custom Worker class.
  #
  class Worker
    include Backburner::Helpers
    include Backburner::Logger

    # Backburner::Worker.known_queue_classes
    # List of known_queue_classes
    class << self
      attr_writer :known_queue_classes
      def known_queue_classes; @known_queue_classes ||= []; end
    end

    # Enqueues a job to be processed later by a worker.
    # Options: `pri` (priority), `delay` (delay in secs), `ttr` (time to respond), `queue` (queue name)
    #
    # @raise [Beaneater::NotConnected] If beanstalk fails to connect.
    # @example
    #   Backburner::Worker.enqueue NewsletterSender, [self.id, user.id], :ttr => 1000
    #
    def self.enqueue(job_class, args=[], opts={})
      pri   = opts[:pri] || job_class.queue_priority || Backburner.configuration.default_priority
      delay = [0, opts[:delay].to_i].max
      ttr   = opts[:ttr] || Backburner.configuration.respond_timeout
      tube  = connection.tubes[expand_tube_name(opts[:queue]  || job_class)]
      res = job_class.invoke_hook_events(:before_enqueue, *args)
      return false unless res # stop if hook is false
      data = { :class => job_class.name, :args => args }
      tube.put data.to_json, :pri => pri, :delay => delay, :ttr => ttr
      job_class.invoke_hook_events(:after_enqueue, *args)
      return true
    end

    # Starts processing jobs with the specified tube_names.
    #
    # @example
    #   Backburner::Worker.start(["foo.tube.name"])
    #
    def self.start(tube_names=nil)
      self.new(tube_names).start
    end

    # Returns the worker connection.
    # @example
    #   Backburner::Worker.connection # => <Beaneater::Pool>
    def self.connection(opts={})
      @connection ||= Backburner.configuration.establish_connection(opts)
    end

    # List of tube names to be watched and processed
    attr_accessor :tube_names

    # Constructs a new worker for processing jobs within specified tubes.
    #
    # @example
    #   Worker.new(['test.job'])
    def initialize(tube_names=nil)
      @tube_names = self.process_tube_names(tube_names)
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

    # Reserves one job within the specified queues.
    # Pops the job off and serializes the job to JSON.
    # Each job is performed by invoking `perform` on the job class.
    #
    # @example
    #   @worker.work_one_job
    #
    def work_one_job
      job = Backburner::Job.new(self.connection.tubes.reserve)
      self.log_job_begin(job.name, job.args)
      job.process(self.connection.iron_mq?)
      self.log_job_end(job.name)
    rescue Backburner::Job::JobFormatInvalid => e
      self.log_error self.exception_message(e)
    rescue => e # Error occurred processing job
      self.log_error self.exception_message(e)
      num_retries = job.stats.releases
      retry_status = "failed: attempt #{num_retries+1} of #{config.max_job_retries+1}"
      if num_retries < config.max_job_retries # retry again
        delay = config.retry_delay + num_retries ** 3
        job.release(:delay => delay)
        self.log_job_end(job.name, "#{retry_status}, retrying in #{delay}s") if job_started_at
      else # retries failed, bury
        job.bury
        self.log_job_end(job.name, "#{retry_status}, burying") if job_started_at
      end
      handle_error(e, job.name, job.args)
    end

    protected

    # Returns a list of all tubes known within the system
    # Filtered for tubes that match the known prefix
    def all_existing_queues
      known_queues    = Backburner::Worker.known_queue_classes.map(&:queue)
      existing_tubes  = self.connection.tubes.all.map(&:name).select { |tube| tube =~ /^#{config.tube_namespace}/ }
      known_queues + existing_tubes
    end

    # Returns a reference to the beanstalk connection
    def connection
      self.class.connection
    end

    # Handles an error according to custom definition
    # Used when processing a job that errors out
    def handle_error(e, name, args)
      if error_handler = Backburner.configuration.on_error
        if error_handler.arity == 1
          error_handler.call(e)
        else
          error_handler.call(e, name, args)
        end
      end
    end

    # Normalizes tube names given array of tube_names
    # Compacts nil items, flattens arrays, sets tubes to nil if no valid names
    # Loads default tubes when no tubes given.
    def compact_tube_names(tube_names)
      tube_names = tube_names.first if tube_names && tube_names.size == 1 && tube_names.first.is_a?(Array)
      tube_names = Array(tube_names).compact if tube_names && Array(tube_names).compact.size > 0
      tube_names = nil if tube_names && tube_names.compact.empty?
      tube_names ||= Backburner.default_queues.any? ? Backburner.default_queues : all_existing_queues
      Array(tube_names)
    end
  end # Worker
end # Backburner