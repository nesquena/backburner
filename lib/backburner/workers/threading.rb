require 'concurrent'

module Backburner
  module Workers
    class Threading < Worker
      class << self
        attr_accessor :shutdown
        attr_accessor :threads_number
      end

      # Custom initializer just to set @tubes_data
      def initialize(*args)
        @tubes_data = {}
        super
        self.process_tube_options
      end

      # Used to prepare job queues before processing jobs.
      # Setup beanstalk tube_names and watch all specified tubes for jobs.
      #
      # @raise [Beaneater::NotConnected] If beanstalk fails to connect.
      # @example
      #   @worker.prepare
      #
      def prepare
        self.tube_names.map! { |name| expand_tube_name(name)  }.uniq!
        log_info "Working #{tube_names.size} queues: [ #{tube_names.join(', ')} ]"
        @thread_pools = {}
        @tubes_data.each do |name, config|
          max_threads = (config[:threads] || self.class.threads_number || ::Concurrent.processor_count).to_i
          @thread_pools[name] = (::Concurrent::ThreadPoolExecutor.new(min_threads: 1, max_threads: max_threads))
        end
      end

      # Starts processing new jobs indefinitely.
      # Primary way to consume and process jobs in specified tubes.
      #
      # @example
      #   @worker.start
      #
      def start(wait=true)
        prepare

        @thread_pools.each do |tube_name, pool|
          pool.max_length.times do
            # Create a new connection and set it up to listen on this tube name
            connection_pool = new_connection_pool.tap{ |conn_pool| conn_pool.active_connections.map{|conn| conn.tubes.watch!(tube_name)} }
            connection_pool.on_reconnect = lambda { |conn_pool| conn_pool.active_connections.map{|conn| conn.tubes.watch!(tube_name)} }

            # Make it work jobs using its own connection per thread
            pool.post(connection_pool) { |connection_pool|
              loop {
                begin
                  work_one_job(connection_pool)

                rescue => e
                  log_error("Exception caught in thread pool loop. Continuing. -> #{e.message}\nBacktrace: #{e.backtrace}")
                end
              }
            }
          end
        end

        wait_for_shutdown! if wait
      end

      # FIXME: We can't use this on_reconnect method since we don't know which thread
      # pool the connection belongs to (and therefore we can't re-watch the right tubes).
      # However, we set the individual connections' on_reconnect method in #start
      # def on_reconnect(conn)
      #   watch_tube(@watching_tube, conn) if @watching_tube
      # end

      # Process the special tube_names of Threading worker:
      #   The format is tube_name:custom_threads_limit
      #
      # @example
      #    process_tube_names(['foo:10', 'lol'])
      #    => ['foo', lol']
      def process_tube_names(tube_names)
        names = compact_tube_names(tube_names)
        if names.nil?
          nil
        else
          names.map do |name|
            data = name.split(":")
            tube_name = data.first
            threads_number = data[1].empty? ? nil : data[1].to_i rescue nil
            @tubes_data[expand_tube_name(tube_name)] = {
              :threads => threads_number
            }
            tube_name
          end
        end
      end

      # Process the tube settings
      # This overrides @tubes_data set by process_tube_names method. So a tube has name 'super_job:5'
      # and the tube class has setting queue_jobs_limit 10, the result limit will be 10
      # If the tube is known by existing beanstalkd queue, but not by class - skip it
      #
      def process_tube_options
        Backburner::Worker.known_queue_classes.each do |queue|
          next if @tubes_data[expand_tube_name(queue)].nil?
          queue_settings = {
            :threads => queue.queue_jobs_limit
          }
          @tubes_data[expand_tube_name(queue)].merge!(queue_settings){|k, v1, v2| v2.nil? ? v1 : v2 }
        end
      end

      # Wait for the shutdown signel
      def wait_for_shutdown!
        while !self.class.shutdown do
          sleep 0.5
        end

        # Shutting down
        # FIXME: Shut down each thread's connection
        @thread_pools.each { |name, pool| pool.kill }
      end

      def shutdown
        Backburner::Workers::Threading.shutdown = true
        super
      end
    end # Threading
  end # Workers
end # Backburner
