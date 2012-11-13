require 'logger'

module Backburner
  module Logger
    # Loads in instance and class levels
    def self.included(base)
      base.extend self
    end

    # Print out when a job is about to begin
    def log_job_begin(name, args)
      log_info "Work job #{name} with #{args.inspect}"
      @job_started_at = Time.now
    end

    # Print out when a job completed
    # If message is nil, job is considered complete
    def log_job_end(name, message = nil)
      ellapsed = Time.now - job_started_at
      ms = (ellapsed.to_f * 1000).to_i
      action_word = message ? 'Finished' : 'Completed'
      log_info("#{action_word} #{name} in #{ms}ms #{message}")
    end

    # Returns true if the job logging started
    def job_started_at
      @job_started_at
    end

    # Print a message to stdout
    #
    # @example
    #   log_info("Working on task")
    #
    def log_info(msg)
      logger ? logger.info(msg) : puts(msg)
    end

    # Print an error to stderr
    #
    # @example
    #   log_error("Task failed!")
    #
    def log_error(msg)
      logger ? logger.error(msg) : $stderr.puts(msg)
    end

    # Return logger if specified
    def logger
      Backburner.configuration.logger
    end
  end
end