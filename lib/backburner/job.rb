module Backburner
  # A single backburner job which can be processed and removed by the worker
  class Job < SimpleDelegator
    include Backburner::Helpers

    # Raises when a job times out
    class JobTimeout < RuntimeError; end
    class JobNotFound < RuntimeError; end
    class JobFormatInvalid < RuntimeError; end
    class RetryJob < RuntimeError; end

    attr_accessor :task, :body, :name, :args

    # Construct a job to be parsed and processed
    #
    # task is a reserved object containing the json body in the form of
    #   { :class => "NewsletterSender", :args => ["foo@bar.com"] }
    #
    # @example
    #  Backburner::Job.new(payload)
    #
    def initialize(task)
      @hooks = Backburner::Hooks
      @task = task
      @body = task.body.is_a?(Hash) ? task.body : Backburner.configuration.job_parser_proc.call(task.body)
      @name = body["class"] || body[:class]
      @args = body["args"] || body[:args]
    rescue => ex # Job was not valid format
      self.bury
      raise JobFormatInvalid, "Job body could not be parsed: #{ex.inspect}"
    end

    # Sets the delegator object to the underlying beaneater job
    # self.bury
    def __getobj__
      __setobj__(@task)
      super
    end

    # Processes a job and handles any failure, deleting the job once complete
    #
    # @example
    #   @task.process
    #
    def process
      # Invoke before hook and stop if false
      res = @hooks.invoke_hook_events(job_name, :before_perform, *args)
      unless res
        task.delete # aborted: don't leave it reserved, or beanstalkd hands it out again after its TTR
        return false
      end
      # Execute the job
      @hooks.around_hook_events(job_name, :around_perform, *args) do
        # We subtract one to ensure we timeout before beanstalkd does, except if
        # ttr == 1 (beanstalkd's minimum: it stores a ttr of 0 as 1), so that we
        # don't accidentally set it to never time out.
        #  NB: A ttr of 1 will likely result in race conditions between
        #  Backburner and beanstalkd and should probably be avoided
        timeout_job_after(task.ttr > 1 ? task.ttr - 1 : task.ttr) { job_class.perform(*args) }
      end
      task.delete
      # Invoke after perform hook
      @hooks.invoke_hook_events(job_name, :after_perform, *args)
    rescue => e
      @hooks.invoke_hook_events(job_name, :on_failure, e, *args)
      raise e
    end

    def bury
      @hooks.invoke_hook_events(job_name, :on_bury, *args)
      task.bury
    end

    def retry(count, delay)
      @hooks.invoke_hook_events(job_name, :on_retry, count, delay, *args)
      task.release(delay: delay)
    end

    # Returns the class for the job handler
    #
    # @example
    #   job_class # => NewsletterSender
    #
    def job_class
      handler = try_job_class
      raise(JobNotFound, @job_class_error ? "#{name} (#{@job_class_error.class}: #{@job_class_error.message.to_s.lines.first.to_s.chomp})" : name) unless handler
      handler
    end

    # Whether the last lookup of the job's class found it missing (not defined, or an autoload whose
    # file isn't there) rather than failing to load it (its file raised, or required a missing gem)
    def job_class_missing?
      !!@job_class_missing
    end

    protected

    # Attempts to return a constantized job name, otherwise reverts to the name string
    #
    # @example
    #   job_name # => "SomeUnknownJob"
    def job_name
      handler = try_job_class
      handler ? handler : self.name
    end

    def try_job_class
      @job_class_error = nil
      @job_class_missing = false
      scope = segment = autoload_path = nil
      invalid_name = !constant_names(self.name).all? { |name| constant_name?(name) }
      constantize(self.name) do |mod, name|
        scope, segment = mod, name
        autoload_path = mod.autoload?(name) rescue nil # a module, or the value of a constant that isn't one
      end
    rescue StandardError, ScriptError => e # its file may raise anything; an autoloader may raise LoadError for a file that isn't there
      @job_class_error = e
      @job_class_missing = !invalid_name && missing_constant_error?(e, scope, segment, autoload_path)
      nil
    end

    # Whether a name can be a constant's: one that can't ("not a class", "123") will never be found
    def constant_name?(name)
      Module.new.const_defined?(name, false) # raises NameError for one that can't
      true
    rescue NameError
      false
    end

    # Whether an error raised while looking up `segment` in `scope` says that constant is missing,
    # rather than coming from inside the file that defines it (a NameError for another constant, or for
    # one of the same name in another module, a NoMethodError, a require of a missing gem, any other
    # error or a syntax error)
    def missing_constant_error?(e, scope, segment, autoload_path)
      case e
      when NoMethodError then false
      when NameError then e.name.to_s == segment.to_s && (e.receiver.equal?(scope) rescue true) # no receiver: by name only
      when LoadError then e.path.nil? || e.path == autoload_path
      else false
      end
    end

    # Timeout job within specified block after given time.
    #
    # @example
    #   timeout_job_after(3) { do_something! }
    #
    def timeout_job_after(secs, &block)
      begin
        Timeout::timeout(secs) { yield }
      rescue Timeout::Error => e
        raise JobTimeout, "#{name}(#{(@args||[]).join(', ')}) hit #{secs}s timeout.\nbacktrace: #{e.backtrace}"
      end
    end

  end # Job
end # Backburner
