require 'backburner/job'

module Backburner
  class Worker
    include Backburner::Helpers
    include Backburner::Logger

    # Backburner::Worker.known_queue_classes
    # List of known_queue_classes
    class << self
      attr_writer :known_queue_classes
      def known_queue_classes; @known_queue_classes ||= []; end
    end

    # Enqueues a job to be processed later by a worker
    # Options: `pri` (priority), `delay` (delay in secs), `ttr` (time to respond), `queue` (queue name)
    #
    # @raise [Beanstalk::NotConnected] If beanstalk fails to connect.
    # @example
    #   Backburner::Worker.enqueue NewsletterSender, [self.id, user.id], :ttr => 1000
    #
    def self.enqueue(job_class, args=[], opts={})
      pri   = opts[:pri] || Backburner.configuration.default_priority
      delay = [0, opts[:delay].to_i].max
      ttr   = opts[:ttr] || Backburner.configuration.respond_timeout
      connection.use expand_tube_name(opts[:queue]  || job_class)
      data = { :class => job_class.name, :args => args }
      connection.put data.to_json, pri, delay, ttr
    end

    # Starts processing jobs in the specified tube_names
    #
    # @example
    #   Backburner::Worker.start(["foo.tube.name"])
    #
    def self.start(tube_names=nil)
      self.new(tube_names).start
    end

    # Returns the worker connection
    # @example
    #   Backburner::Worker.connection # => <Beanstalk::Pool>
    def self.connection
      @connection ||= Connection.new(Backburner.configuration.beanstalk_url)
    end

    # List of tube names to be watched and processed
    attr_accessor :tube_names

    # @example
    #   Worker.new(['test.job'])
    def initialize(tube_names=nil)
      @tube_names = begin
        tube_names = tube_names.first if tube_names && tube_names.size == 1 && tube_names.first.is_a?(Array)
        tube_names = Array(tube_names).compact if tube_names && Array(tube_names).compact.size > 0
        tube_names = nil if tube_names && tube_names.compact.empty?
        tube_names
      end
    end

    # Starts processing new jobs indefinitely
    # Primary way to consume and process jobs in specified tubes
    #
    # @example
    #   @worker.start
    #
    def start
      prepare
      loop { work_one_job }
    end

    # Setup beanstalk tube_names and watch all specified tubes for jobs.
    # Used to prepare job queues before processing jobs.
    #
    # @raise [Beanstalk::NotConnected] If beanstalk fails to connect.
    # @example
    #   @worker.prepare
    #
    def prepare
      self.tube_names ||= Backburner.default_queues.any? ? Backburner.default_queues : all_existing_queues
      self.tube_names = Array(self.tube_names)
      self.tube_names.map! { |name| expand_tube_name(name)  }
      log "Working #{tube_names.size} queues: [ #{tube_names.join(', ')} ]"
      self.tube_names.uniq.each { |name| self.connection.watch(name) }
      self.connection.list_tubes_watched.each do |server, tubes|
        tubes.each { |tube| self.connection.ignore(tube) unless self.tube_names.include?(tube) }
      end
    end

    # Reserves one job within the specified queues
    # Pops the job off and serializes the job to JSON
    # Each job is performed by invoking `perform` on the job class.
    #
    # @example
    #   @worker.work_one_job
    #
    def work_one_job
      job = Backburner::Job.new(self.connection.reserve)
      self.class.log_job_begin(job.body)
      job.process
      self.class.log_job_end(job.name)
    rescue => e
      job.bury
      self.class.log_error self.class.exception_message(e)
      self.class.log_job_end(job.name, 'failed') if @job_begun
      handle_error(e, job.name, job.args)
    end

    protected

    # Returns a list of all tubes known within the system
    # Filtered for tubes that match the known prefix
    def all_existing_queues
      known_queues    = Backburner::Worker.known_queue_classes.map(&:queue)
      existing_tubes  = self.connection.list_tubes.values.flatten.uniq.select { |tube| tube =~ /^#{tube_namespace}/ }
      known_queues + existing_tubes
    end

    # Returns a reference to the beanstalk connection
    def connection
      self.class.connection
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
  end # Worker
end # Backburner