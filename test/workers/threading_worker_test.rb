require File.expand_path('../../test_helper', __FILE__)
require File.expand_path('../../fixtures/test_jobs', __FILE__)
require File.expand_path('../../fixtures/hooked', __FILE__)

describe "Backburner::Workers::Threading worker" do
  before do
    Backburner.default_queues.clear
    @worker_class = Backburner::Workers::Threading
  end

  describe "for prepare method" do
    it "should make tube names array always unique to avoid duplication" do
      worker = @worker_class.new(["foo", "demo.test.foo"])
      worker.prepare
      assert_equal ["demo.test.foo"], worker.tube_names
    end

    it 'creates a thread pool per queue' do
      worker = @worker_class.new(%w(foo bar))
      out = capture_stdout { worker.prepare }
      assert_equal 2, worker.instance_variable_get("@thread_pools").keys.size
    end

    it 'uses Concurrent.processor_count if no custom thread count is provided' do
      worker = @worker_class.new("foo")
      out = capture_stdout { worker.prepare }
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
    end

    it 'runs work_on_job per thread' do
      clear_jobs!("foo")
      job_count=10
      job_count.times { @worker_class.enqueue TestJob, [1, 0], :queue => "foo" } # TestJob adds the given arguments together and then to $worker_test_count
      @worker.start(false) # don't wait for shutdown
      sleep 0.5 # Wait for threads to do their work
      assert_equal job_count, $worker_test_count
    end
  end # working a queue
end
