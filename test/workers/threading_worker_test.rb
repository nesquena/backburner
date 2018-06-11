require File.expand_path('../../test_helper', __FILE__)
require File.expand_path('../../fixtures/test_jobs', __FILE__)
require File.expand_path('../../fixtures/hooked', __FILE__)

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

  describe 'working a queue' do
    before do
      @worker = @worker_class.new(["foo:3"])
      capture_stdout { @worker.prepare }
      $worker_test_count = 0
      $worker_success = false
    end

    it 'runs work_on_job per thread' do
      clear_jobs!("foo")
      job_count=10
      # TestJob adds the given arguments together and then to $worker_test_count
      job_count.times { @worker_class.enqueue TestJob, [1, 0], :queue => "foo" }
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

    it 'forces an exit when a job is stuck' do
      6.times { @worker_class.enqueue TestStuckJob, [1, 0], :queue => "threaded-shutdown" }
      Thread.new { sleep 0.1; @worker.self_write.puts("TERM") }
      capture_stdout do
        @worker.start
      end

      assert_equal 0, $worker_test_count
    end
  end
end
