require 'logger'

module Backburner
  module Logger
    # Loads in instance and class levels
    def self.included(base)
      base.extend self
    end

    # Print out when a job is about to begin
    def log_job_begin(body)
      log_info [ "Working", body ].join(' ')
      @job_started_at = Time.now
    end

    # Returns true if the job logging started
    def job_started_at
      @job_started_at
    end

    # Print out when a job completed
    def log_job_end(name, failed=false)
      ellapsed = Time.now - job_started_at
      ms = (ellapsed.to_f * 1000).to_i
      log_info "Finished #{name} in #{ms}ms #{failed ? ' (failed)' : ''}"
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