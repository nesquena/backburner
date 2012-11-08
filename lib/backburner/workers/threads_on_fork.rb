module Backburner
  module Workers
    class Fork < Worker

      # Custom initializer just to set @tubes_data
      def initialize(*args)
        @tubes_data = {}
        super
      end

      # Process the special tube_names of Fork worker
      # The idea is tube_name:custom_threads_limit:custom_garbage_limit:custom_retries
      # Any custom can be ignore. So if you want to set just the custom_retries
      # you will need to write this 'tube_name:::10'
      #
      # @example
      #    process_tube_names(['foo:10:5:1', 'bar:2::3', 'lol'])
      #    => ['foo', 'bar', 'lol']
      def process_tube_names(tube_names)
        compact_tube_names(tube_names).map do |name|
          data = name.split(":")
          tube_name = data.first
          threads_number = data[1].to_i rescue nil
          garbage_number = data[2].to_i rescue nil
          retries_number = data[3].to_i rescue nil
          @tubes_data[tube_name] = {
              :threads => threads_number,
              :retries => retries_number,
              :garbage => garbage_number
          }
          tube_name
        end
      end

      def prepare
        self.tube_names ||= begin
          names = Backburner.default_queues.any? ? Backburner.default_queues : all_existing_queues
          Array(names)
        end
      end

      # For each tube we will call fork_and_watch to create the fork
      # The lock argument define if this method should block or no
      def start(lock=true)
        tube_names.each do |name|
          fork_and_watch(name)
        end

        if lock
          sleep 0.1 while true
        end
      end

      # Make the fork and create a thread to watch the child process
      # The exit code '99' means that the fork exited because of the garbage limit
      # Any other code is an error
      def fork_and_watch(name)
        process_id = fork_tube(name)
        create_thread(process_id, name) do |pid, tube_name|
          _, status = wait_for_process(pid)

          # 99 = garbaged
          if status.exitstatus != 99
            log_error("Catastrophic failure: tube #{tube_name} exited with code #{status.exitstatus}.")
          end
          fork_and_watch(tube_name)
        end
      end

      # This makes easy to test
      def fork_tube(name)
        fork do
          fork_inner(name)
        end
      end

      # Here we are already on the forked child
      # We will watch just the selected tube and change the configuration of
      # config.max_job_retries if needed
      #
      # If we limit the number of threads to 1 it will just run in a loop without
      # creating any extra thread.
      def fork_inner(name)
        expanded_name = expand_tube_name(name)
        connection.tubes.watch!([expanded_name])

        if @tubes_data[name]
          config.max_job_retries if @tubes_data[name][:retries]
        end
        @garbage_after  = @tubes_data[name][:garbage] rescue self.class.garbage_after
        @threads_number = (@tubes_data[name][:threads] rescue self.class.threads_number || 1).to_i

        @runs = 0

        if @threads_number == 1
          run_while_can
        else
          threads_count = Thread.list.count
          threads.times do
            create_thread do
              run_while_can
            end
          end
          sleep 0.1 while Thread.list.count > threads_count
        end

        coolest_exit
      end

      # Run work_one_job while we can
      def run_while_can
        while @garbage_after.nil? or @garbade_after > @runs
          @runs += 1
          work_one_job
        end
      end

      # Exit with Kernel.exit! to avoid at_exit callbacks that should belongs to
      # parent process
      # We will use exitcode 99 that means the fork reached the garbage number
      def coolest_exit
        Kernel.exit! 99
      end

      # Create a thread. Easy to test
      def create_thread(*args, &block)
        Thread.new(*args, &block)
      end

      # Wait for a specific process. Easy to test
      def wait_for_process(pid)
        Process.wait2(pid)
      end

    end
  end
end