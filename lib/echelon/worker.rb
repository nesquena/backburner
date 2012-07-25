module Echelon
  class Worker
    include Echelon::Helpers
    include Echelon::Logger

    # Raises when a job times out
    class JobNotFound < RuntimeError; end
    class JobTimeout < RuntimeError; end
    class JobQueueNotSet < RuntimeError; end

    # Enqueues a job to be performed
    # Options include `pri` (priority), `delay` (delay in secs), `ttr` (time to respond)
    # Echelon::Worker.enqueue NewsletterSender, [self.id, user.id], :ttr => 1000
    def self.enqueue(job_class, args=[], opts={})
      pri   = opts[:pri] || Echelon.configuration.default_priority
      delay = [0, opts[:delay].to_i].max
      ttr   = opts[:ttr] || Echelon.configuration.respond_timeout
      queue = opts[:queue] ? [tube_namespace, opts[:queue]].join(".") : nil
      connection.use queue || job_queue_name(job_class, args)
      data = { :class => job_class, :args => args }
      connection.put data.to_json, pri, delay, ttr
    rescue Beanstalk::NotConnected => e
      failed_connection(e)
    end

    # Starts processing jobs in the specified tube_names
    def self.start(tube_names=nil)
      self.new(tube_names).start
    end

    # Returns the worker connection
    def self.connection
      @connection ||= Connection.new(Echelon.configuration.beanstalk_url)
    end

    attr_accessor :tube_names

    # Worker.new(['test.job'])
    def initialize(tube_names=nil)
      @tube_names = tube_names if tube_names && tube_names.size > 0
    end

    def start(&block)
      prepare
      loop { work_one_job }
    end

    def prepare
      self.tube_names ||= all_queues
      self.tube_names = Array(self.tube_names)
      self.tube_names.map! { |name| name =~ /^#{tube_namespace}/ ? name : [tube_namespace, name].join(".")  }
      log "Working #{tube_names.size} queues: [ #{tube_names.join(' ')} ]"
      self.tube_names.each { |name| self.connection.watch(name) }
      self.connection.list_tubes_watched.each do |server, tubes|
        tubes.each { |tube| self.connection.ignore(tube) unless self.tube_names.include?(tube) }
      end
    rescue Beanstalk::NotConnected => e
      failed_connection(e)
    end

    def work_one_job
      job = self.connection.reserve
      body = JSON.parse job.body
      name, args = body["class"], body["args"]
      self.class.log_job_begin(body)
      handler = constantize(name)
      raise(JobNotFound, name) unless handler

      begin
        Timeout::timeout(job.ttr - 1) do
          handler.perform(*args)
        end
      rescue Timeout::Error
        raise JobTimeout, "#{name} hit #{job.ttr-1}s timeout"
      end

      job.delete
      self.class.log_job_end(name)
    rescue Beanstalk::NotConnected => e
      failed_connection(e)
    rescue SystemExit
      raise
    rescue => e
      job.bury
      self.class.log_error self.class.exception_message(e)
      self.class.log_job_end(name, 'failed') if @job_begun
      handle_error(e, name, args)
    end

    protected

    def all_queues
      self.connection.list_tubes.values.flatten.uniq.select { |tube|
        tube =~ /^#{tube_namespace}/
      }
    end

    # Returns the queue_name for a particular job
    # job_queue_name(NewsletterSender, [5, 10]) => "newsletter-sender"
    def self.job_queue_name(job_class, args)
      job_name = if job_class.respond_to?(:queue_name) # queue_name is set
        job_class.queue_name
      elsif job_class.respond_to?(:echelon_performable?) # auto-name based on performable
        [dasherize(job_class), args[1].to_s].join("-")
      else # no queue name
        raise JobQueueNotSet, "Please set the queue name for #{job_class}!"
      end
      [tube_namespace, job_name].join(".")
    end

    # Returns a reference to the beanstalk connection
    def connection
      self.class.connection
    end

    # Handles an error according to custom definition
    def handle_error(e, name, args)
      if error_handler = Echelon.configuration.on_error
        if error_handler.arity == 1
          error_handler.call(e)
        else
          error_handler.call(e, name, args)
        end
      end
    end
  end # Worker

  # Prints message about failure
  def failed_connection(e)
    log_error exception_message(e)
    log_error "*** Failed connection to #{beanstalk_url}"
    log_error "*** Check that beanstalkd is running (or set a different BEANSTALK_URL)"
    exit 1
  end
end # Echelon