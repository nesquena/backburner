require 'celluloid'

module Backburner
  # A single backburner job which can be processed and removed by the worker
  class Job
    include Celluloid
    include Backburner::Helpers
    include Backburner::Logger

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
    def initialize(supervisor)
      @supervisor = supervisor
    end

    # Processes a job and handles any failure, deleting the job once complete
    #
    # @example
    #   @task.process
    #
    def process(task)
      @task = task
      @body = JSON.parse(task.body)
      puts "Processing #{task.body}"
      @name, @args = body["class"], body["args"]
      handler = job_class
      log_job_begin(body)
      guard_job_for(task.ttr - 1) { handler.perform(*args) }
      task.delete
      log_job_end(name)
      @supervisor.processor_done(current_actor)
    end

    protected

    # Returns the class for the job handler
    #
    # @example
    #   job_class # => NewsletterSender
    #
    def job_class
      handler = constantize(name) rescue nil
      raise JobNotFound, name unless handler
      handler
    end

    # Guard job from exceptions and enforce timeout after given seconds
    #
    # @example
    #   guard_job_for(3) { do_something! }
    #
    def guard_job_for(secs, &block)
      begin
        Timeout::timeout(secs) { yield }
      rescue Timeout::Error
        raise JobTimeout, "#{name} hit #{secs}s timeout"
      rescue Beanstalk::NotConnected => e
        failed_connection(e)
      rescue SystemExit
        raise
      rescue => e
        task.bury
        log_error exception_message(e)
        log_job_end(name, 'failed') if @job_begun
        handle_error(e, name, args)
      end
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
  end # Job
end # Backburner