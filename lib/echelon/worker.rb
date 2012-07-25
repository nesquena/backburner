module Echelon
  class Worker
    include Echelon::Helpers
    include Echelon::Logger

    class JobNotFound < RuntimeError; end
    class JobTimeout < RuntimeError; end
    class JobQueueNotSet < RuntimeError; end

    # Enqueues a job to be processed later by a worker
    # Options: `pri` (priority), `delay` (delay in secs), `ttr` (time to respond), `queue` (queue name)
    # Echelon::Worker.enqueue NewsletterSender, [self.id, user.id], :ttr => 1000
    def self.enqueue(job_class, args=[], opts={})
      pri   = opts[:pri] || Echelon.configuration.default_priority
      delay = [0, opts[:delay].to_i].max
      ttr   = opts[:ttr] || Echelon.configuration.respond_timeout
      connection.use job_queue_name(opts[:queue]  || job_class)
      data = { :class => job_class, :args => args }
      connection.put data.to_json, pri, delay, ttr
    rescue Beanstalk::NotConnected => e
      failed_connection(e)
    end

    # Starts processing jobs in the specified tube_names
    # Echelon::Worker.start(["foo.tube.name"])
    def self.start(tube_names=nil)
      self.new(tube_names).start
    end

    # Returns the worker connection
    # Echelon::Worker.connection => <Beanstalk::Pool>
    def self.connection
      @connection ||= Connection.new(Echelon.configuration.beanstalk_url)
    end

    # List of tube names to be watched and processed
    attr_accessor :tube_names

    # Worker.new(['test.job'])
    def initialize(tube_names=nil)
      @tube_names = tube_names if tube_names && tube_names.size > 0
    end

    # Starts processing new jobs indefinitely
    # Primary way to consume and process jobs in specified tubes
    # @worker.start
    def start
      prepare
      loop { work_one_job }
    end

    # Setup beanstalk tube_names and watch all specified tubes for jobs.
    # Used to prepare job queues before processing jobs.
    # @worker.prepare
    def prepare
      self.tube_names ||= Echelon.default_queues.any? ? Echelon.default_queues : all_existing_queues
      self.tube_names = Array(self.tube_names)
      self.tube_names.map! { |name| name =~ /^#{tube_namespace}/ ? name : [tube_namespace, name].join(".")  }
      log "Working #{tube_names.size} queues: [ #{tube_names.join(', ')} ]"
      self.tube_names.each { |name| self.connection.watch(name) }
      self.connection.list_tubes_watched.each do |server, tubes|
        tubes.each { |tube| self.connection.ignore(tube) unless self.tube_names.include?(tube) }
      end
    rescue Beanstalk::NotConnected => e
      failed_connection(e)
    end

    # Reserves one job within the specified queues
    # Pops the job off and serializes the job to JSON
    # Each job is performed by invoking `perform` on the job class.
    # @worker.work_one_job
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

    # Returns a list of all tubes known within the system
    # Filtered for tubes that match the known prefix
    def all_existing_queues
      self.connection.list_tubes.values.flatten.uniq.select { |tube|
        tube =~ /^#{tube_namespace}/
      }
    end

    # Returns the queue_name for a particular job
    # job_queue_name(NewsletterSender, [5, 10]) => "newsletter-sender"
    def self.job_queue_name(job_class)
      job_name = if job_class.is_a?(String)
        dasherize(job_class)
      elsif job_class.respond_to?(:queue) # use queue name
        job_class.queue
      else # no queue name, use job_class
        dasherize(job_class.name)
      end
      [tube_namespace, job_name].join(".")
    end

    # Returns a reference to the beanstalk connection
    def connection
      self.class.connection
    end

    # Handles an error according to custom definition
    # Used when processing a job that errors out
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

  # Prints message about failure when beastalk cannot be connected
  def failed_connection(e)
    log_error exception_message(e)
    log_error "*** Failed connection to #{connection.url}"
    log_error "*** Check that beanstalkd is running (or set a different beanstalk url)"
    exit 1
  end
end # Echelon