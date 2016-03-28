module Backburner
  module Workers
    class Threading < Worker
      # Used to prepare job queues before processing jobs.
      # Setup beanstalk tube_names and watch all specified tubes for jobs.
      #
      # @raise [Beaneater::NotConnected] If beanstalk fails to connect.
      # @example
      #   @worker.prepare
      #
      def prepare
        @queue_options = {}
        self.tube_names.map! { |name|
          # queue can be in format queue:number_of_threads
          # number_of_threads is 1 by default
          data = name.split(":")
          tube_name = expand_tube_name(data.first)
          @queue_options[tube_name] = {}
          @queue_options[tube_name][:number_of_threads] = data[1].nil? || data[1].empty? ? 1 : data[1].to_i
          tube_name
        }.uniq!
        log_info "[Threading worker] Working #{tube_names.size} queues: [ #{tube_names.join(', ')} ]"
      end

      # Starts processing new jobs indefinitely.
      # Primary way to consume and process jobs in specified tubes.
      #
      # @example
      #   @worker.start
      #
      def start
        prepare

        threads = []
        self.tube_names.each do |tube_name|
          @queue_options[tube_name][:number_of_threads].times do
            threads << Thread.new do
              log_info "[Threading worker] Watching queue : #{tube_name}"
              Thread.current[:tube_name] = tube_name
              Thread.current[:conn] = new_connection()
              Thread.current[:conn].tubes.watch!(Thread.current[:tube_name])
              loop {
                work_one_job(Thread.current[:conn])
              }
            end
          end
        end

        threads.each { |thread| thread.join }
      end

      def on_reconnect(conn)
        unless Thread.current[:tube_name].nil? then
          log_info "[Threading worker] Trying to recover connection for queue #{Thread.current[:tube_name]}"
          Thread.current[:conn] = conn
          Thread.current[:conn].tubes.watch!(Thread.current[:tube_name])
        end
      end
    end
  end
end
