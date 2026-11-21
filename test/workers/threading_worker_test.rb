require File.expand_path('../../test_helper', __FILE__)
require File.expand_path('../../fixtures/test_jobs', __FILE__)
require File.expand_path('../../fixtures/hooked', __FILE__)
require File.expand_path('../../fixtures/test_queue_settings', __FILE__)

describe "Backburner::Workers::Threading worker" do
  before do
    Backburner.default_queues.clear
    @worker_class = Backburner::Workers::Threading
    @worker_class.shutdown_timeout = 2
  end

  describe "for prepare method" do
    it "should make tube names array always unique to avoid duplication" do
      worker = @worker_class.new(["foo", "demo.test.foo"])
      capture_stdout { worker.prepare }
      assert_equal ["demo.test.foo"], worker.tube_names
    end

    it 'creates a thread pool per queue' do
      worker = @worker_class.new(%w(foo bar))
      capture_stdout { worker.prepare }
      assert_equal 2, worker.instance_variable_get("@thread_pools").keys.size
    end

    it 'uses Concurrent.processor_count if no custom thread count is provided' do
      worker = @worker_class.new("foo")
      capture_stdout { worker.prepare }
      assert_equal ::Concurrent.processor_count, worker.instance_variable_get("@thread_pools")["demo.test.foo"].max_length
    end
  end # prepare

  describe "for process_tube_names method" do
    it "should interpret the job_name:threads_limit format" do
      worker = @worker_class.new(["foo:4"])
      assert_equal ["foo"], worker.tube_names
    end

    it "should interpret correctly even if missing values" do
      tubes = %W(foo1:2 foo2)
      worker = @worker_class.new(tubes)
      assert_equal %W(foo1 foo2), worker.tube_names
    end

    it "should store interpreted values correctly" do
      tubes = %W(foo1 foo2:2)
      worker = @worker_class.new(tubes)
      assert_equal({
        "demo.test.foo1" => { :threads => nil },
        "demo.test.foo2" => { :threads => 2 }
      }, worker.instance_variable_get("@tubes_data"))
    end
  end # process_tube_names

  describe "for process_tube_options method" do
    it "should take a shared tube's limit from the class that owns the tube, not from subclasses" do
      worker = @worker_class.new(%w(tube-limits tube-limits-testtubelimitslambdachildjob))
      assert_equal({
        "demo.test.tube-limits" => { :threads => 5 },
        "demo.test.tube-limits-testtubelimitslambdachildjob" => { :threads => 4 }
      }, worker.instance_variable_get("@tubes_data"))
    end

    it "should fill in a shared tube's limit from a subclass when the tube's class sets none" do
      worker = @worker_class.new(%w(tube-few-limits))
      assert_equal({ "demo.test.tube-few-limits" => { :threads => 3 } }, worker.instance_variable_get("@tubes_data"))
    end
  end # process_tube_options

  describe 'working a queue' do
    before do
      @worker = @worker_class.new(["threaded-work:3"])
      capture_stdout { @worker.prepare }
      $worker_test_count = 0
      $worker_success = false
    end

    # Its threads would otherwise keep taking jobs from its tube for the rest of the run
    after do
      @worker.exit_on_shutdown = false
      capture_stdout { @worker.shutdown }
    end

    it 'runs work_on_job per thread' do
      clear_jobs!("threaded-work")
      job_count=10
      # TestJob adds the given arguments together and then to $worker_test_count
      job_count.times { @worker_class.enqueue TestJob, [1, 0], :queue => "threaded-work" }
      capture_stdout do
        @worker.start(false) # don't wait for shutdown
        sleep 0.5 # Wait for threads to do their work
      end
      assert_equal job_count, $worker_test_count
    end
  end # working a queue

  describe 'shutting down' do
    before do
      @thread_count = 3
      @worker = @worker_class.new(["threaded-shutdown:#{@thread_count}"])
      @worker.exit_on_shutdown = false
      $worker_test_count = 0
      clear_jobs!("threaded-shutdown")
    end

    it 'gracefully exits and completes all in-flight jobs' do
      6.times { @worker_class.enqueue TestSlowJob, [1, 0], :queue => "threaded-shutdown" }
      Thread.new { sleep 0.1; @worker.self_write.puts("TERM") }
      capture_stdout do
        @worker.start
      end

      assert_equal @thread_count, $worker_test_count
    end

    # Its threads wait in reserve: they must see the shutdown, not be killed at shutdown_timeout
    it 'exits promptly when idle' do
      previous, @worker_class.shutdown_timeout = @worker_class.shutdown_timeout, 10
      Thread.new { sleep 0.5; @worker.self_write.puts("TERM") }
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      capture_stdout do
        @worker.start
      end

      assert_operator Process.clock_gettime(Process::CLOCK_MONOTONIC) - started, :<, 3
    ensure
      @worker_class.shutdown_timeout = previous
    end

    # A reserve_timeout read from the environment is a String, a negative one waits forever, and Infinity has no to_i
    it 'exits promptly and works jobs with a String or negative reserve_timeout' do
      previous = Backburner.configuration.reserve_timeout
      previous_shutdown_timeout, @worker_class.shutdown_timeout = @worker_class.shutdown_timeout, 10
      ["5", -1, Float::INFINITY].each do |timeout|
        Backburner.configure { |config| config.reserve_timeout = timeout }
        worker = @worker_class.new(["threaded-work:3"])
        worker.exit_on_shutdown = false
        capture_stdout { worker.prepare }
        $worker_test_count = 0
        clear_jobs!("threaded-work")
        @worker_class.enqueue TestJob, [1, 0], :queue => "threaded-work"
        Thread.new { sleep 0.5; worker.self_write.puts("TERM") }
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        capture_stdout { worker.start }

        assert_equal 1, $worker_test_count, "reserve_timeout #{timeout.inspect}"
        assert_operator Process.clock_gettime(Process::CLOCK_MONOTONIC) - started, :<, 3, "reserve_timeout #{timeout.inspect}"
      end
    ensure
      Backburner.configure { |config| config.reserve_timeout = previous }
      @worker_class.shutdown_timeout = previous_shutdown_timeout
    end

    # Its own tube and worker: the jobs it leaves reserved go back to ready when their connections are
    # finalized, and must not reach another test's workers
    it 'forces an exit when a job is stuck' do
      clear_jobs!("threaded-stuck")
      @worker = @worker_class.new(["threaded-stuck:#{@thread_count}"])
      @worker.exit_on_shutdown = false
      6.times { @worker_class.enqueue TestStuckJob, [1, 0], :queue => "threaded-stuck" }
      Thread.new { sleep 0.1; @worker.self_write.puts("TERM") }
      capture_stdout do
        @worker.start
      end

      assert_equal 0, $worker_test_count
    end

    it 'logs exceptions escaping work_one_job in the pool loop and keeps working' do
      clear_jobs!("threaded-loop-rescue")
      @worker_class.enqueue TestJob, [2, 3], :queue => "threaded-loop-rescue"
      worker = @worker_class.new(["threaded-loop-rescue:1"])
      worker.exit_on_shutdown = false
      calls = 0
      worker.define_singleton_method(:work_one_job) do |conn = connection|
        calls += 1
        if calls == 1
          raise Beaneater::NotConnected, "lost connection"
        elsif calls == 2
          super(conn)
          self_write.puts("TERM")
        end
      end

      out = silenced(5) { worker.start }
      assert_match(/Exception caught in thread pool loop\. Continuing\. -> lost connection/, out)
      assert_equal 5, $worker_test_count
    ensure
      worker.connection.close if worker && worker.connection
      clear_jobs!("threaded-loop-rescue")
    end

    it 'skips wait_for_termination once shutdown_timeout is exhausted and kills only running pools' do
      previous_timeout = @worker_class.shutdown_timeout
      @worker_class.shutdown_timeout = 0
      worker = @worker_class.new(["threaded-a:1", "threaded-b:1"])
      worker.exit_on_shutdown = false

      done_pool = mock('done_pool')
      done_pool.expects(:shutdown)
      done_pool.expects(:wait_for_termination).never
      done_pool.expects(:shutdown?).returns(true)
      done_pool.expects(:kill).never

      stuck_pool = mock('stuck_pool')
      stuck_pool.expects(:shutdown)
      stuck_pool.expects(:wait_for_termination).never
      stuck_pool.expects(:shutdown?).returns(false)
      stuck_pool.expects(:kill).once

      worker.instance_variable_set(:@thread_pools, { "a" => done_pool, "b" => stuck_pool })
      capture_stdout { worker.shutdown_threadpools }
    ensure
      @worker_class.shutdown_timeout = previous_timeout
      worker.connection.close if worker && worker.connection
    end

    it 'aborts graceful shutdown on Interrupt and kills remaining pools immediately' do
      worker = @worker_class.new(["threaded-abort:1"])
      worker.exit_on_shutdown = false

      done_pool = mock('done_pool')
      done_pool.expects(:shutdown)
      done_pool.expects(:wait_for_termination).raises(Interrupt)
      done_pool.expects(:shutdown?).returns(true)
      done_pool.expects(:kill).never

      stuck_pool = mock('stuck_pool')
      stuck_pool.expects(:shutdown)
      stuck_pool.expects(:shutdown?).returns(false)
      stuck_pool.expects(:kill).once

      worker.instance_variable_set(:@thread_pools, { "a" => done_pool, "b" => stuck_pool })
      out = capture_stdout { worker.shutdown_threadpools }
      assert_match(/graceful shutdown aborted, shutting down immediately/, out)
    ensure
      worker.connection.close if worker && worker.connection
    end

    it 'writes the signal to self_write before shutdown and raises Interrupt on a second signal' do
      prev_term = Signal.trap('TERM', 'DEFAULT')
      Signal.trap('TERM', prev_term)
      prev_int = Signal.trap('INT', 'DEFAULT')
      Signal.trap('INT', prev_int)

      worker = @worker_class.new(["threaded-signal:1"])
      Process.kill('TERM', Process.pid)
      assert IO.select([worker.self_read], nil, nil, 2), "expected TERM trap to write to self_write"
      assert_equal "TERM\n", worker.self_read.gets

      worker.instance_variable_set(:@in_shutdown, true)
      assert_raises(Interrupt) do
        Timeout.timeout(2) do
          Process.kill('TERM', Process.pid)
          loop { Thread.pass }
        end
      end
    ensure
      Signal.trap('TERM', prev_term) if prev_term
      Signal.trap('INT', prev_int) if prev_int
      worker.self_read.close if worker && worker.self_read && !worker.self_read.closed?
      worker.self_write.close if worker && worker.self_write && !worker.self_write.closed?
      worker.connection.close if worker && worker.connection
    end
  end
end
