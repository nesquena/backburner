module Backburner
  # A single backburner job which can be processed and removed by the worker
  class Job < SimpleDelegator
    include Backburner::Helpers

    # Raises when a job times out
    class JobTimeout < RuntimeError; end
    class JobNotFound < RuntimeError; end
    class JobFormatInvalid < RuntimeError; end

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
      @task = task
      @body = task.body.is_a?(Hash) ? task.body : JSON.parse(task.body)
      @name, @args = body["class"], body["args"]
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
    def process(skip_timeout = false)
      # Invoke before hook and stop if false
      res = job_class.invoke_hook_events(:before_perform, *args)
      return false unless res
      # Execute the job
      job_class.around_hook_events(:around_perform, *args) do
        ttr = skip_timeout ? 0 : task.ttr - 1
        timeout_job_after(ttr) { job_class.perform(*args) }
      end
      task.delete
      # Invoke after perform hook
      job_class.invoke_hook_events(:after_perform, *args)
    rescue => e
      job_class.invoke_hook_events(:on_failure, e, *args)
      raise e
    end

    protected

    # Returns the class for the job handler
    #
    # @example
    #   job_class # => NewsletterSender
    #
    def job_class
      handler = constantize(self.name) rescue nil
      raise(JobNotFound, self.name) unless handler
      handler
    end

    # Timeout job within specified block after given time.
    #
    # @example
    #   timeout_job_after(3) { do_something! }
    #
    def timeout_job_after(secs, &block)
      begin
        Timeout::timeout(secs) { yield }
      rescue Timeout::Error
        raise JobTimeout, "#{name} hit #{secs}s timeout"
      end
    end

  end # Job
end # Backburner