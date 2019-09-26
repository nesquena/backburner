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
      return false unless res
      # Execute the job
      @hooks.around_hook_events(job_name, :around_perform, *args) do
        # We subtract one to ensure we timeout before beanstalkd does, except if:
        #  a) ttr == 0, to support never timing out
        #  b) ttr == 1, so that we don't accidentally set it to never time out
        #  NB: A ttr of 1 will likely result in race conditions between
        #  Backburner and beanstalkd and should probably be avoided
        start_job { job_class.perform(*args) }
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

    def touch
      @hooks.invoke_hook_events(job_name, :on_touch, *args)
      task.touch
    end

    protected

    # Returns the class for the job handler
    #
    # @example
    #   job_class # => NewsletterSender
    #
    def job_class
      handler = try_job_class
      raise(JobNotFound, self.name) unless handler
      handler
    end

    # Attempts to return a constantized job name, otherwise reverts to the name string
    #
    # @example
    #   job_name # => "SomeUnknownJob"
    def job_name
      handler = try_job_class
      handler ? handler : self.name
    end

    def try_job_class
      constantize(self.name)
    rescue NameError
      nil
    end

    # Start the specified block using the same timeout as beaneater.
    #
    # @example
    #   start_job { do_something! }
    #
    def start_job(&block)
      return yield if task.stats.ttr == 0

      current_thread = Thread.current
      block_thread = Thread.start do
        begin
          yield
        rescue JobTimeout => e
          current_thread.raise JobTimeout, "#{name}(#{(@args||[]).join(', ')}) hit #{task.stats.ttr}s timeout.\nbacktrace: #{e.backtrace}"
        rescue => e
          current_thread.raise e
        end
      end
      timer_thread = job_timer(block_thread)
      block_thread.join
      timer_thread.kill
    end

    # Start a thread checking the time left of the job from beanstalk.
    # If timed out, bury the job and raise an error on the job's thread to make it stop.
    #
    # @example
    #   job_timer(thread)
    #
    def job_timer(watched_thread)
      Thread.start do
        while(task.stats.time_left > 0) do
          sleep(task.stats.time_left)
        end

        if watched_thread.alive?
          # If we don't bury the job here, beaneater return a NOT_FOUND error when work_one_job tries to bury it
          task.bury
          watched_thread.raise JobTimeout.new
        end
      end
    end

  end # Job
end # Backburner
