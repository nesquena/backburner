module Backburner
  module Workers
    class ThreadsOnFork < Worker

      class << self
        attr_accessor :shutdown
        attr_accessor :threads_number
        attr_accessor :garbage_after
        attr_accessor :is_child

        # return the pids of all alive children/forks
        def child_pids
          return [] if is_child
          @child_pids ||= []
          tmp_ids = []
          for id in @child_pids
            next if id.to_i == Process.pid
            begin
              Process.kill(0, id)
              tmp_ids << id
            rescue Errno::ESRCH => e
            end
          end
          @child_pids = tmp_ids if @child_pids != tmp_ids
          @child_pids
        end

        # Send a SIGTERM signal to all children
        # This is the same of a normal exit
        # We are simply asking the children to exit
        def stop_forks
          for id in child_pids
            begin
              Process.kill("SIGTERM", id)
            rescue Errno::ESRCH
            end
          end
        end

        # Send a SIGKILL signal to all children
        # This is the same of assassinate
        # We are KILLING those folks that don't obey us
        def kill_forks
          for id in child_pids
            begin
              Process.kill("SIGKILL", id)
            rescue Errno::ESRCH
            end
          end
        end

        def finish_forks
          return if is_child
          ids = child_pids
          if ids.length > 0
            puts "[ThreadsOnFork workers] Stopping forks: #{ids.join(", ")}"
            stop_forks
            Kernel.sleep 1
            ids = child_pids
            if ids.length > 0
              puts "[ThreadsOnFork workers] Killing remaining forks: #{ids.join(", ")}"
              kill_forks
              Process.waitall
            end
          end
        end
      end

      # Custom initializer just to set @tubes_data
      def initialize(*args)
        @tubes_data = {}
        super
        self.process_tube_options
      end

      # Process the special tube_names of ThreadsOnFork worker
      # The idea is tube_name:custom_threads_limit:custom_garbage_limit:custom_retries
      # Any custom can be ignore. So if you want to set just the custom_retries
      # you will need to write this 'tube_name:::10'
      #
      # @example
      #    process_tube_names(['foo:10:5:1', 'bar:2::3', 'lol'])
      #    => ['foo', 'bar', 'lol']
      def process_tube_names(tube_names)
        names = compact_tube_names(tube_names)
        if names.nil?
          nil
        else
          names.map do |name|
            data = name.split(":")
            tube_name = data.first
            threads_number = data[1].empty? ? nil : data[1].to_i rescue nil
            garbage_number = data[2].empty? ? nil : data[2].to_i rescue nil
            retries_number = data[3].empty? ? nil : data[3].to_i rescue nil
            @tubes_data[expand_tube_name(tube_name)] = {
                :threads => threads_number,
                :garbage => garbage_number,
                :retries => retries_number
            }
            tube_name
          end
        end
      end

      # Process the tube settings
      # This overrides @tubes_data set by process_tube_names method. So a tube has name 'super_job:5:20:10'
      # and the tube class has setting queue_jobs_limit 10, the result limit will be 10
      # If the tube is known by existing beanstalkd queue, but not by class - skip it
      #
      def process_tube_options
        Backburner::Worker.known_queue_classes.each do |queue|
          next if @tubes_data[expand_tube_name(queue)].nil?
          queue_settings = {
              :threads => queue.queue_jobs_limit,
              :garbage => queue.queue_garbage_limit,
              :retries => queue.queue_retry_limit
          }
          @tubes_data[expand_tube_name(queue)].merge!(queue_settings){|k, v1, v2| v2.nil? ? v1 : v2 }
        end
      end

      def prepare
        self.tube_names ||= Backburner.default_queues.any? ? Backburner.default_queues : all_existing_queues
        self.tube_names = Array(self.tube_names)
        tube_names.map! { |name| expand_tube_name(name)  }
        tube_display_names = tube_names.map{|name| "#{name}:#{@tubes_data[name].values}"}
        log_info "Working #{tube_names.size} queues: [ #{tube_display_names.join(', ')} ]"
      end

      # For each tube we will call fork_and_watch to create the fork
      # The lock argument define if this method should block or no
      def start(lock=true)
        prepare
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
        create_thread(name) do |tube_name|
          until self.class.shutdown
            pid = fork_tube(tube_name)
            _, status = wait_for_process(pid)

            # 99 = garbaged
            if status.exitstatus != 99
              log_error("Catastrophic failure: tube #{tube_name} exited with code #{status.exitstatus}.")
            end
          end
        end
      end

      # This makes easy to test
      def fork_tube(name)
        fork_it do
          fork_inner(name)
        end
      end

      # Here we are already on the forked child
      # We will watch just the selected tube and change the configuration of
      # queue_config.max_job_retries if needed
      #
      # If we limit the number of threads to 1 it will just run in a loop without
      # creating any extra thread.
      def fork_inner(name)
        watch_tube(name)

        if @tubes_data[name]
          queue_config.max_job_retries = @tubes_data[name][:retries] if @tubes_data[name][:retries]
        else
          @tubes_data[name] = {}
        end
        @garbage_after  = @tubes_data[name][:garbage]  || self.class.garbage_after
        @threads_number = (@tubes_data[name][:threads] || self.class.threads_number || 1).to_i

        @runs = 0

        if @threads_number == 1
          run_while_can(name)
        else
          threads_count = Thread.list.count
          @threads_number.times do
            create_thread do
              conn = Connection.new(Backburner.configuration.beanstalk_url)
              begin
                run_while_can(name, conn)
              ensure
                conn.close
              end
            end
          end
          sleep 0.1 while Thread.list.count > threads_count
        end

        coolest_exit
      end

      # Run work_one_job while we can
      def run_while_can(name, conn = nil)
        conn ||= connection
        watch_tube(name, conn)
        while @garbage_after.nil? or @garbage_after > @runs
          @runs += 1
          work_one_job(conn)
        end
      end

      # Shortcut for watching a tube on beanstalk connection
      def watch_tube(name, conn = nil)
        conn ||= connection
        conn.tubes.watch!(name)
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
        out = Process.wait2(pid)
        self.class.child_pids.delete(pid)
        out
      end

      # Forks the specified block and adds the process to the child process pool
      def fork_it(&blk)
        pid = Kernel.fork do
          self.class.is_child = true
          $0 = "[ThreadsOnFork worker] parent: #{Process.ppid}"
          @connection = Connection.new(Backburner.configuration.beanstalk_url)
          blk.call
        end
        self.class.child_pids << pid
        pid
      end

      def connection
        @connection || super
      end

    end
  end
end

at_exit do
  unless Backburner::Workers::ThreadsOnFork.is_child
    Backburner::Workers::ThreadsOnFork.shutdown = true
  end
  Backburner::Workers::ThreadsOnFork.finish_forks
end
