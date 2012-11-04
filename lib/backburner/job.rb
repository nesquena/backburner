module Backburner
  # A single backburner job which can be processed and removed by the worker
  class Job
    include Backburner::Helpers

    # Raises when a job times out
    class JobTimeout < RuntimeError; end
    class JobNotFound < RuntimeError; end

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
    end

    # Processes a job and handles any failure, deleting the job once complete
    #
    # @example
    #   @task.process
    #
    def process
      timeout_job_after(task.ttr - 1) { job_class.perform(*args) }
      task.delete
    end

    # Bury a job out of the active queue if that job fails
    def bury
      task.bury
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

    # Timeout job after given time
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