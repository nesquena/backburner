require File.expand_path('../../test_helper', __FILE__)
require File.expand_path('../../fixtures/test_forking_jobs', __FILE__)

describe "Backburner::Workers::Forking module" do

  before do
    Backburner.default_queues.clear
    @worker_class = Backburner::Workers::Forking
  end

  describe "for fork_one_job method" do

    it "should fork, reconnect, work job, and exit" do
      clear_jobs!("bar.foo")
      @worker_class.enqueue TestJobForking, [1, 2], :queue => "bar.foo"

      fake_pid = 45
      Process.expects(:fork).returns(fake_pid) do |&block|
        Connection.expects(:new).with(Backburner.configuration.beanstalk_url)
        @worker_class.any_instance.expects(:work_one_job)
        @worker_class.any_instance.expects(:coolest_exit)
        block.call
      end
      Process.expects(:wait).with(fake_pid)

      silenced(2) do
        worker = @worker_class.new('bar.foo')
        worker.prepare
        worker.fork_one_job
      end
    end

  end # fork_one_job

  describe "practical tests" do

    before do
      @templogger = Templogger.new('/tmp')
      Backburner.configure { |config| config.logger = @templogger.logger }
      $worker_test_count = 0
      $worker_success = false
      $worker_raise   = false
      clear_jobs!('response')
      clear_jobs!('bar.foo.1', 'bar.foo.2', 'bar.foo.3', 'bar.foo.4', 'bar.foo.5')
      silenced do
        @response_worker = @worker_class.new('response')
      end
    end

    after do
      @templogger.close
      clear_jobs!('response')
      clear_jobs!('bar.foo.1', 'bar.foo.2', 'bar.foo.3', 'bar.foo.4', 'bar.foo.5')
    end


    it "should work an enqueued job" do
      @worker = @worker_class.new('bar.foo.1')
      @worker_class.enqueue TestJobForking, [1, 2], :queue => "bar.foo.1"
      @worker.prepare
      @worker.fork_one_job
      silenced(2) do
        @templogger.wait_for_match(/Completed TestJobFork/m)
        @response_worker.prepare
        @response_worker.work_one_job
      end
      assert_equal 3, $worker_test_count
    end # enqueue

    it "should work for an async job" do
      @worker = @worker_class.new('bar.foo.2')
      TestAsyncJobForking.async(:queue => 'bar.foo.2').foo(3, 5)
      @worker.prepare
      @worker.fork_one_job
      silenced(2) do
        @templogger.wait_for_match(/Completed TestAsyncJobFork/m)
        @response_worker.prepare
        @response_worker.work_one_job
      end
      assert_equal 15, $worker_test_count
    end # async

    it "should fail quietly if there's an argument error" do
      Backburner.configure { |config| config.max_job_retries = 0 }
      @worker = @worker_class.new('bar.foo.3')
      @worker_class.enqueue TestJobForking, ["bam", "foo", "bar"], :queue => "bar.foo.3"
      @worker.prepare
      @worker.fork_one_job
      silenced(5) do
        @templogger.wait_for_match(/Finished TestJobFork.*attempt 1 of 1/m)
      end
      assert_match(/Exception ArgumentError/, @templogger.body)
      assert_equal 0, $worker_test_count
    end # fail, argument

    it "should support retrying jobs and burying" do
      Backburner.configure { |config| config.max_job_retries = 1; config.retry_delay = 0 }
      @worker = @worker_class.new('bar.foo.4')
      @worker_class.enqueue TestRetryJobForking, ["bam", "foo"], :queue => 'bar.foo.4'
      @worker.prepare
      2.times do
        $worker_test_count += 1
        @worker.fork_one_job
      end
      silenced(2) do
        @templogger.wait_for_match(/Finished TestRetryJobFork.*attempt 2 of 2/m)
        @response_worker.prepare
        2.times { @response_worker.work_one_job }
      end
      assert_equal 4, $worker_test_count
      assert_equal false, $worker_success
    end # retry, bury

    it "should support retrying jobs and succeeds" do
      Backburner.configure { |config| config.max_job_retries = 2; config.retry_delay = 0 }
      @worker = @worker_class.new('bar.foo.5')
      @worker_class.enqueue TestRetryJobForking, ["bam", "foo"], :queue => 'bar.foo.5'
      @worker.prepare
      3.times do
        $worker_test_count += 1
        @worker.fork_one_job
      end
      silenced(2) do
        @templogger.wait_for_match(/Completed TestRetryJobFork/m)
        @response_worker.prepare
        3.times { @response_worker.work_one_job }
      end
      assert_equal 6, $worker_test_count
      assert_equal true, $worker_success
    end # retrying, succeeds

  end # practical tests


end
