require File.expand_path('../../test_helper', __FILE__)
require File.expand_path('../../fixtures/test_fork_jobs', __FILE__)
require File.expand_path('../../fixtures/test_queue_settings', __FILE__)

describe "Backburner::Workers::ThreadsOnFork module" do

  before do
    Backburner.default_queues.clear
    @worker_class = Backburner::Workers::ThreadsOnFork
    @worker_class.shutdown = false
    @worker_class.is_child = false
    @worker_class.threads_number = 1
    @worker_class.garbage_after = 1
    @ignore_forks = false
  end

  after do
    Backburner.configure { |config| config.max_job_retries = 0; config.retry_delay = 5; config.logger = nil }
    unless @ignore_forks
      cpids = @worker_class.instance_variable_get("@child_pids")
      if cpids && cpids.length > 0
        raise "Why is there forks alive?"
      end
    end
  end

  describe "for process_tube_names method" do
    it "should interpreter the job_name:threads_limit:garbage_after:retries format" do
      worker = @worker_class.new(["foo:1:2:3"])
      assert_equal ["foo"], worker.tube_names
    end

    it "should interpreter event if is missing values" do
      tubes = %W(foo1:1:2:3 foo2:4:5 foo3:6 foo4 foo5::7:8 foo6:::9 foo7::10)
      worker = @worker_class.new(tubes)
      assert_equal %W(foo1 foo2 foo3 foo4 foo5 foo6 foo7), worker.tube_names
    end

    it "should store interpreted values correctly" do
      tubes = %W(foo1:1:2:3 foo2:4:5 foo3:6 foo4 foo5::7:8 foo6:::9 foo7::10)
      worker = @worker_class.new(tubes)
      assert_equal({
        "demo.test.foo1" => { :threads => 1,   :garbage => 2,   :retries => 3   },
        "demo.test.foo2" => { :threads => 4,   :garbage => 5,   :retries => nil },
        "demo.test.foo3" => { :threads => 6,   :garbage => nil, :retries => nil },
        "demo.test.foo4" => { :threads => nil, :garbage => nil, :retries => nil },
        "demo.test.foo5" => { :threads => nil, :garbage => 7,   :retries => 8   },
        "demo.test.foo6" => { :threads => nil, :garbage => nil, :retries => 9   },
        "demo.test.foo7" => { :threads => nil, :garbage => 10,  :retries => nil }
      }, worker.instance_variable_get("@tubes_data"))
    end
  end

  describe "for process_tube_settings" do
    it "should set the settings specified by queue name in class" do
      worker = @worker_class.new
      assert_equal(worker.instance_variable_get("@tubes_data")['demo.test.job-settings'],  { :threads => 5,   :garbage => 10,   :retries => 6 })
    end

    it 'should override the tube settings if they are specified directly at class level' do
      worker = @worker_class.new
      assert_equal(worker.instance_variable_get("@tubes_data")['demo.test.job-settings-override'], { :threads => 10,   :garbage => 1000,   :retries => 2 })
    end
  end

  describe "for prepare method" do
    before do
      Backburner.configure { |config| config.logger = false }
    end

    it "should watch specified tubes" do
      worker = @worker_class.new(["foo", "bar"])
      out = capture_stdout { worker.prepare }
      assert_equal ["demo.test.foo", "demo.test.bar"], worker.tube_names
      assert_match /demo\.test\.foo/, out
    end # multiple

    it "should watch single tube" do
      worker = @worker_class.new("foo")
      out = capture_stdout { worker.prepare }
      assert_equal ["demo.test.foo"], worker.tube_names
      assert_match /demo\.test\.foo/, out
    end # single

    it "should respect default_queues settings" do
      Backburner.default_queues.concat(["foo", "bar"])
      worker = @worker_class.new
      out = capture_stdout { worker.prepare }
      assert_equal ["demo.test.foo", "demo.test.bar"], worker.tube_names
      assert_match /demo\.test\.foo/, out
    end

    it "should assign based on all tubes" do
      @worker_class.any_instance.expects(:all_existing_queues).once.returns("bar")
      worker = @worker_class.new
      out = capture_stdout { worker.prepare }
      assert_equal ["demo.test.bar"], worker.tube_names
      assert_match /demo\.test\.bar/, out
    end # all assign

    it "should properly retrieve all tubes" do
      worker = @worker_class.new
      out = capture_stdout { worker.prepare }
      assert_contains worker.tube_names, "demo.test.test-job-fork"
      assert_match /demo\.test\.test-job-fork/, out
    end # all read
  end # prepare

  describe "forking and threading" do

    it "start should call fork_and_watch for each tube" do
      worker = @worker_class.new(%W(foo bar))
      worker.expects(:fork_and_watch).with("demo.test.foo").once
      worker.expects(:fork_and_watch).with("demo.test.bar").once
      silenced { worker.start(false) }
    end

    it "fork_and_watch should create a thread to fork and watch" do
      worker = @worker_class.new(%(foo))
      worker.expects(:create_thread).once.with("demo.test.foo")
      silenced { worker.start(false) }
    end

    it "fork_and_watch thread should wait with wait_for_process" do
      process_exit = stub('process_exit')
      process_exit.expects(:exitstatus).returns(99)
      worker = @worker_class.new(%(foo))
      worker.expects(:wait_for_process).with(12).returns([nil, process_exit])

      wc = @worker_class
      # TODO: Is there a best way do do this?
      worker.define_singleton_method :fork_it do
        wc.shutdown = true
        12
      end
      def worker.create_thread(*args, &block); block.call(*args) end

      out = silenced(2) { worker.start(false) }
      refute_match /Catastrophic failure/, out
    end

    it "fork_and_watch thread should log an error if exitstatus is != 99" do
      process_exit = stub('process_exit')
      process_exit.expects(:exitstatus).twice.returns(0)
      worker = @worker_class.new(%(foo))
      worker.expects(:wait_for_process).with(12).returns([nil, process_exit])

      wc = @worker_class
      # TODO: Is there a best way do do this?
      worker.define_singleton_method :fork_it do
        wc.shutdown = true
        12
      end
      def worker.create_thread(*args, &block); block.call(*args) end
      out = silenced(2) { worker.start(false) }
      assert_match /Catastrophic failure: tube demo\.test\.foo exited with code 0\./, out
    end

    describe "fork_inner" do

      before do
        @worker_class.any_instance.expects(:coolest_exit).once
      end

      it "should watch just the channel it receive as argument" do
        worker = @worker_class.new(%(foo))
        @worker_class.expects(:threads_number).returns(1)
        worker.expects(:run_while_can).once
        silenced do
          worker.prepare
          worker.fork_inner('demo.test.bar')
        end
        assert_same_elements %W(demo.test.bar), @worker_class.connection.tubes.watched.map(&:name)
      end

      it "should not create threads if the number of threads is 1" do
        worker = @worker_class.new(%(foo))
        @worker_class.expects(:threads_number).returns(1)
        worker.expects(:run_while_can).once
        worker.expects(:create_thread).never
        silenced do
          worker.prepare
          worker.fork_inner('demo.test.foo')
        end
      end

      it "should create threads if the number of threads is > 1" do
        worker = @worker_class.new(%(foo))
        @worker_class.expects(:threads_number).returns(5)
        worker.expects(:create_thread).times(5)
        silenced do
          worker.prepare
          worker.fork_inner('demo.test.foo')
        end
      end

      it "should create threads that call run_while_can" do
        worker = @worker_class.new(%(foo))
        @worker_class.expects(:threads_number).returns(5)
        worker.expects(:run_while_can).times(5)
        # TODO
        def worker.create_thread(*args, &block); block.call(*args) end
        silenced do
          worker.prepare
          worker.fork_inner('demo.test.foo')
        end
      end

      it "should create a connection for each thread" do
        name = 'demo.test.foo'
        num_threads = 3

        worker = @worker_class.new(%(foo))
        @worker_class.expects(:threads_number).returns(num_threads)
        invocations = Array(1..num_threads).map { |i|
          conn = OpenStruct.new(:num => i)
          conn.expects(:close)
          conn
        }
        Backburner::Connection.expects(:new).times(num_threads).returns(*invocations)

        # ensure each invocation of run_while_can is with a different connection
        num_conns = states('num_conns').starts_as(0)
        invocations.each do |conn|
          worker.expects(:run_while_can).with(name, conn).when(num_conns.is(conn.num-1)).then(num_conns.is(conn.num))
        end

        def worker.create_thread(*args, &block); block.call(*args) end
        silenced do
          worker.prepare
          worker.fork_inner(name)
        end
        assert_equal(num_threads, num_conns.current_state)
      end

      it "should set @garbage_after, @threads_number and set retries if needed" do
        worker = @worker_class.new(%W(foo1 foo2:10 foo3:20:30 foo4:40:50:60))
        default_threads = 1
        default_garbage = 5
        default_retries = 100
        @worker_class.expects(:threads_number).times(1).returns(default_threads)
        @worker_class.expects(:garbage_after).times(2).returns(default_garbage)
        @worker_class.any_instance.expects(:coolest_exit).times(3)
        Backburner.configuration.max_job_retries = default_retries

        worker.expects(:create_thread).times(70)
        worker.expects(:run_while_can).once

        silenced do
          worker.prepare
          worker.fork_inner('demo.test.foo1')
        end

        assert_equal worker.instance_variable_get("@threads_number"), default_threads
        assert_equal worker.instance_variable_get("@garbage_after"), default_garbage
        assert_equal Backburner.configuration.max_job_retries, default_retries

        silenced do
          worker.fork_inner('demo.test.foo2')
        end

        assert_equal worker.instance_variable_get("@threads_number"), 10
        assert_equal worker.instance_variable_get("@garbage_after"), default_garbage
        assert_equal Backburner.configuration.max_job_retries, default_retries

        silenced do
          worker.fork_inner('demo.test.foo3')
        end

        assert_equal worker.instance_variable_get("@threads_number"), 20
        assert_equal worker.instance_variable_get("@garbage_after"), 30
        assert_equal Backburner.configuration.max_job_retries, default_retries

        silenced do
          worker.fork_inner('demo.test.foo4')
        end

        assert_equal worker.instance_variable_get("@threads_number"), 40
        assert_equal worker.instance_variable_get("@garbage_after"), 50
        assert_equal Backburner.configuration.max_job_retries, 60
      end

    end

    describe "cleanup on parent" do

      it "child_pids should return a list of alive children pids" do
        worker = @worker_class.new(%W(foo))
        Kernel.expects(:fork).once.returns(12345)
        Process.expects(:kill).with(0, 12345).once
        Process.expects(:pid).once.returns(12346)
        assert_equal [], @worker_class.child_pids
        worker.fork_it {}
        child_pids = @worker_class.child_pids
        assert_equal [12345], child_pids
        child_pids.clear
      end

      it "child_pids should return an empty array if is_child" do
        Process.expects(:pid).never
        @worker_class.is_child = true
        @worker_class.child_pids << 12345
        assert_equal [], @worker_class.child_pids
      end

      it "stop_forks should send a SIGTERM for every child" do
        Process.expects(:pid).returns(12346).at_least(1)
        Process.expects(:kill).with(0, 12345).at_least(1)
        Process.expects(:kill).with(0, 12347).at_least(1)
        Process.expects(:kill).with("SIGTERM", 12345)
        Process.expects(:kill).with("SIGTERM", 12347)
        @worker_class.child_pids << 12345
        @worker_class.child_pids << 12347
        assert_equal [12345, 12347], @worker_class.child_pids
        @worker_class.stop_forks
        @worker_class.child_pids.clear
      end

      it "kill_forks should send a SIGKILL for every child" do
        Process.expects(:pid).returns(12346).at_least(1)
        Process.expects(:kill).with(0, 12345).at_least(1)
        Process.expects(:kill).with(0, 12347).at_least(1)
        Process.expects(:kill).with("SIGKILL", 12345)
        Process.expects(:kill).with("SIGKILL", 12347)
        @worker_class.child_pids << 12345
        @worker_class.child_pids << 12347
        assert_equal [12345, 12347], @worker_class.child_pids
        @worker_class.kill_forks
        @worker_class.child_pids.clear
      end

      it "finish_forks should call stop_forks, kill_forks and Process.waitall" do
        Process.expects(:pid).returns(12346).at_least(1)
        Process.expects(:kill).with(0, 12345).at_least(1)
        Process.expects(:kill).with(0, 12347).at_least(1)
        Process.expects(:kill).with("SIGTERM", 12345)
        Process.expects(:kill).with("SIGTERM", 12347)
        Process.expects(:kill).with("SIGKILL", 12345)
        Process.expects(:kill).with("SIGKILL", 12347)
        Kernel.expects(:sleep).with(1)
        Process.expects(:waitall)
        @worker_class.child_pids << 12345
        @worker_class.child_pids << 12347
        assert_equal [12345, 12347], @worker_class.child_pids
        silenced do
          @worker_class.finish_forks
        end
        @worker_class.child_pids.clear
      end

      it "finish_forks should not do anything if is_child" do
        @worker_class.expects(:stop_forks).never
        @worker_class.is_child = true
        @worker_class.child_pids << 12345
        silenced do
          @worker_class.finish_forks
        end
      end

    end # cleanup on parent

    describe "practical tests" do

      before do
        @templogger = Templogger.new('/tmp')
        Backburner.configure { |config| config.logger = @templogger.logger }
        $worker_test_count = 0
        $worker_success = false
        $worker_raise   = false
        clear_jobs!('response')
        clear_jobs!('foo.bar.1', 'foo.bar.2', 'foo.bar.3', 'foo.bar.4', 'foo.bar.5', 'foo.bar.6')
        @worker_class.threads_number = 1
        @worker_class.garbage_after  = 10
        silenced do
          @response_worker = @worker_class.new('response')
          @response_worker.watch_tube('demo.test.response')
        end
        @ignore_forks = true
      end

      after do
        @templogger.close
        clear_jobs!('response')
        clear_jobs!('foo.bar.1', 'foo.bar.2', 'foo.bar.3', 'foo.bar.4', 'foo.bar.5', 'foo.bar.6')
        @worker_class.threads_number = 1
        @worker_class.shutdown = true
        silenced do
          @worker_class.stop_forks
          Timeout::timeout(2) { sleep 0.1 while @worker_class.child_pids.length > 0 }
          @worker_class.kill_forks
          Timeout::timeout(2) { sleep 0.1 while @worker_class.child_pids.length > 0 }
        end
      end

      it "should work an enqueued job" do
        @worker = @worker_class.new('foo.bar.1')
        @worker.start(false)
        @worker_class.enqueue TestJobFork, [1, 2], :queue => "foo.bar.1"
        silenced(2) do
          @templogger.wait_for_match(/Completed TestJobFork/m)
          @response_worker.work_one_job
        end
        assert_equal 3, $worker_test_count
      end # enqueue

      it "should work for an async job" do
        @worker = @worker_class.new('foo.bar.2')
        @worker.start(false)
        TestAsyncJobFork.async(:queue => 'foo.bar.2').foo(3, 5)
        silenced(2) do
          @templogger.wait_for_match(/Completed TestAsyncJobFork/m)
          @response_worker.work_one_job
        end
        assert_equal 15, $worker_test_count
      end # async

      it "should fail quietly if there's an argument error" do
        @worker = @worker_class.new('foo.bar.3')
        @worker.start(false)
        @worker_class.enqueue TestJobFork, ["bam", "foo", "bar"], :queue => "foo.bar.3"
        silenced(5) do
          @templogger.wait_for_match(/Finished TestJobFork.*attempt 1 of 1/m)
        end
        assert_match(/Exception ArgumentError/, @templogger.body)
        assert_equal 0, $worker_test_count
      end # fail, argument

      it "should support retrying jobs and burying" do
        Backburner.configure { |config| config.max_job_retries = 1; config.retry_delay = 0 }
        @worker = @worker_class.new('foo.bar.4')
        @worker.start(false)
        @worker_class.enqueue TestRetryJobFork, ["bam", "foo"], :queue => 'foo.bar.4'
        silenced(2) do
          @templogger.wait_for_match(/Finished TestRetryJobFork.*attempt 2 of 2/m)
          2.times { @response_worker.work_one_job }
        end
        assert_equal 2, $worker_test_count
        assert_equal false, $worker_success
      end # retry, bury

      it "should support retrying jobs and succeeds" do
        Backburner.configure { |config| config.max_job_retries = 2; config.retry_delay = 0 }
        @worker = @worker_class.new('foo.bar.5')
        @worker.start(false)
        @worker_class.enqueue TestRetryJobFork, ["bam", "foo"], :queue => 'foo.bar.5'
        silenced(2) do
          @templogger.wait_for_match(/Completed TestRetryJobFork/m)
          3.times { @response_worker.work_one_job }
        end
        assert_equal 3, $worker_test_count
        assert_equal true, $worker_success
      end # retrying, succeeds

      it "should support a multithreaded worker without deadlocks" do
        num_threads = 5
        num_jobs = 8
        num_jobs.times do
          @worker_class.enqueue TestJobFork, [6,2], :queue => 'foo.bar.6'
        end
        @worker_class.threads_number = num_threads
        @worker = @worker_class.new('foo.bar.6')
        @worker.start(false)
        silenced(2) do
          @templogger.wait_for_match(/Completed TestJobFork/m)
          num_jobs.times { @response_worker.work_one_job }
        end
        assert_equal num_jobs, $worker_test_count
      end # multithreaded

    end # practical tests

  end # forking and threading

end # Backburner::Workers::ThreadsOnFork module
