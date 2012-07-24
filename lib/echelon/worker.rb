module Echelon
  class Worker
    # Enqueues a job to be performed
    # Options include `pri` (priority), `delay` (delay in secs), `ttr` (time to respond)
    def self.enqueue(job_class, args={}, opts={})
      pri   = opts[:pri] || Echelon.configuration.default_priority
      delay = [0, opts[:delay].to_i].max
      ttr   = opts[:ttr] || Echelon.configuration.respond_timeout
      connection.use job_class.tube_name
      data = { :job_class => job_class, :args => args }
      connection.put data.to_json, pri, delay, ttr
    rescue Beanstalk::NotConnected => e
      failed_connection(e)
    end

    # Returns the worker connection
    def self.connection
      @connection ||= Connection.new(Echelon.configuration.beanstalk_url)
    end

    protected

    def failed_connection(e)
      log_error exception_message(e)
      log_error "*** Failed connection to #{beanstalk_url}"
      log_error "*** Check that beanstalkd is running (or set a different BEANSTALK_URL)"
      exit 1
    end

    def log_error(msg)
      STDERR.puts msg
    end

    def exception_message(e)
      msg = [ "Exception #{e.class} -> #{e.message}" ]

      base = File.expand_path(Dir.pwd) + '/'
      e.backtrace.each do |t|
        msg << "   #{File.expand_path(t).gsub(/#{base}/, '')}"
      end

      msg.join("\n")
    end
  end # Worker
end # Echelon