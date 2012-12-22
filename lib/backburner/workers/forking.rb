module Backburner
  module Workers
    class Forking < Worker

      def prepare
        self.tube_names.map! { |name| expand_tube_name(name)  }
        log_info "Working #{tube_names.size} queues: [ #{tube_names.join(', ')} ]"
        self.connection.tubes.watch!(*self.tube_names)
      end

      def start
        prepare
        loop { fork_one_job }
      end

      def fork_one_job
        pid = Process.fork do
          @connection = Connection.new(Backburner.configuration.beanstalk_url)
          work_one_job
        end
        Process.wait(pid)
      end

    end
  end
end
