module Backburner
  module Workers
    class Forking < Worker
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
        self.connection_pool.connections.each do |conn|
          conn.tubes.watch!(*self.tube_names)
        end
      end

      # Starts processing new jobs indefinitely.
      # Primary way to consume and process jobs in specified tubes.
      #
      # @example
      #   @worker.start
      #
      def start
        prepare
        loop { fork_one_job }
      end

      # Need to re-establish the connection to the server(s) after forking
      # Waits for a job, works the job, and exits
      def fork_one_job
        pid = Process.fork do
          work_one_job
          coolest_exit
        end
        Process.wait(pid)
      end

      def on_reconnect(conn)
        @connection = conn
        prepare
      end

      # Exit with Kernel.exit! to avoid at_exit callbacks that should belongs to
      # parent process
      # We will use exitcode 99 that means the fork reached the garbage number
      def coolest_exit
        Kernel.exit! 99
      end

    end
  end
end
