module Echelon
  module Logger

    def self.included(base)
      base.extend self
    end

    def log_job_begin(body)
      log [ "Working", body ].join(' ')
      @job_begun = Time.now
    end

    def log_job_end(name, failed=false)
      ellapsed = Time.now - @job_begun
      ms = (ellapsed.to_f * 1000).to_i
      log "Finished #{name} in #{ms}ms #{failed ? ' (failed)' : ''}"
    end

    def log(msg)
      puts msg
    end

    def log_error(msg)
      $stderr.puts msg
    end

  end
end