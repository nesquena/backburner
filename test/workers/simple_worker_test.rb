require File.expand_path('../../test_helper', __FILE__)
require File.expand_path('../../fixtures/test_jobs', __FILE__)
require File.expand_path('../../fixtures/hooked', __FILE__)

describe "Backburner::Workers::Basic module" do
  before do
    Backburner.default_queues.clear
    @worker_class = Backburner::Workers::Simple
  end

  describe "for prepare method" do
    it "should watch specified tubes" do
      worker = @worker_class.new(["foo", "bar"])
      out = capture_stdout { worker.prepare }
      assert_equal ["demo.test.foo", "demo.test.bar"], worker.tube_names
      assert_same_elements ["demo.test.foo", "demo.test.bar"], @worker_class.connection.tubes.watched.map(&:name)
      assert_match /demo\.test\.foo/, out
    end # multiple

    it "should watch single tube" do
      worker = @worker_class.new("foo")
      out = capture_stdout { worker.prepare }
      assert_equal ["demo.test.foo"], worker.tube_names
      assert_same_elements ["demo.test.foo"], @worker_class.connection.tubes.watched.map(&:name)
      assert_match /demo\.test\.foo/, out
    end # single

    it "should respect default_queues settings" do
      Backburner.default_queues.concat(["foo", "bar"])
      worker = @worker_class.new
      out = capture_stdout { worker.prepare }
      assert_equal ["demo.test.foo", "demo.test.bar"], worker.tube_names
      assert_same_elements ["demo.test.foo", "demo.test.bar"], @worker_class.connection.tubes.watched.map(&:name)
      assert_match /demo\.test\.foo/, out
    end

    it "should assign based on all tubes" do
      @worker_class.any_instance.expects(:all_existing_queues).once.returns("bar")
      worker = @worker_class.new
      out = capture_stdout { worker.prepare }
      assert_equal ["demo.test.bar"], worker.tube_names
      assert_same_elements ["demo.test.bar"], @worker_class.connection.tubes.watched.map(&:name)
      assert_match /demo\.test\.bar/, out
    end # all assign

    it "should properly retrieve all tubes" do
      worker = @worker_class.new
      out = capture_stdout { worker.prepare }
      assert_contains worker.tube_names, "demo.test.backburner-jobs"
      assert_contains @worker_class.connection.tubes.watched.map(&:name), "demo.test.backburner-jobs"
      assert_match /demo\.test\.test-job/, out
    end # all read
  end # prepare

  describe "for work_one_job method" do
    before do
      $worker_test_count = 0
      $worker_success = false
    end

    it "should work a plain enqueued job" do
      clear_jobs!("foo.bar")
      @worker_class.enqueue TestPlainJob, [1, 2], :queue => "foo.bar"
      silenced(2) do
        worker = @worker_class.new('foo.bar')
        worker.prepare
        worker.work_one_job
      end
      assert_equal 4, $worker_test_count
    end # plain enqueue

    it "should work an enqueued job" do
      clear_jobs!("foo.bar")
      @worker_class.enqueue TestJob, [1, 2], :queue => "foo.bar"
      silenced(2) do
        worker = @worker_class.new('foo.bar')
        worker.prepare
        worker.work_one_job
      end
      assert_equal 3, $worker_test_count
    end # enqueue

    it "should fail quietly if there's an argument error" do
      clear_jobs!("foo.bar")
      @worker_class.enqueue TestJob, ["bam", "foo", "bar"], :queue => "foo.bar"
      out = silenced(2) do
        worker = @worker_class.new('foo.bar')
        worker.prepare
        worker.work_one_job
      end
      assert_match(/Exception ArgumentError/, out)
      assert_equal 0, $worker_test_count
    end # fail, argument

    it "should work an enqueued failing job" do
      clear_jobs!("foo.bar")
      @worker_class.enqueue TestFailJob, [1, 2], :queue => "foo.bar"
      Backburner::Job.any_instance.expects(:bury).once
      out = silenced(2) do
        worker = @worker_class.new('foo.bar')
        worker.prepare
        worker.work_one_job
      end
      assert_match(/Exception RuntimeError/, out)
      assert_equal 0, $worker_test_count
    end # fail, runtime error

    it "should work an invalid job parsed" do
      Beaneater::Tubes.any_instance.expects(:reserve).returns(stub(:body => "{%$^}", :bury => true))
      out = silenced(2) do
        worker = @worker_class.new('foo.bar')
        worker.prepare
        worker.work_one_job
      end
      assert_match(/Exception Backburner::Job::JobFormatInvalid/, out)
      assert_equal 0, $worker_test_count
    end # fail, runtime error

    it "should work for an async job" do
      clear_jobs!('foo.bar')
      TestAsyncJob.async(:queue => 'foo.bar').foo(3, 5)
      silenced(2) do
        worker = @worker_class.new('foo.bar')
        worker.prepare
        worker.work_one_job
      end
      assert_equal 15, $worker_test_count
    end # async

    it "should support retrying jobs and burying" do
      clear_jobs!('foo.bar')
      Backburner.configure { |config| config.max_job_retries = 1; config.retry_delay = 0 }
      @worker_class.enqueue TestRetryJob, ["bam", "foo"], :queue => 'foo.bar'
      out = []
      2.times do
        out << silenced(2) do
          worker = @worker_class.new('foo.bar')
          worker.prepare
          worker.work_one_job
        end
      end
      assert_match /attempt 1 of 2, retrying/, out.first
      assert_match /Finished TestRetryJob/m, out.last
      assert_match /attempt 2 of 2, burying/m, out.last
      assert_equal 2, $worker_test_count
      assert_equal false, $worker_success
    end # retry, bury

    it "should support retrying jobs and succeeds" do
      clear_jobs!('foo.bar')
      Backburner.configure { |config| config.max_job_retries = 2; config.retry_delay = 0 }
      @worker_class.enqueue TestRetryJob, ["bam", "foo"], :queue => 'foo.bar'
      out = []
      3.times do
        out << silenced(2) do
          worker = @worker_class.new('foo.bar')
          worker.prepare
          worker.work_one_job
        end
      end
      assert_match /attempt 1 of 3, retrying/, out.first
      assert_match /attempt 2 of 3, retrying/, out[1]
      assert_match /Completed TestRetryJob/m, out.last
      refute_match(/failed/, out.last)
      assert_equal 3, $worker_test_count
      assert_equal true, $worker_success
    end # retrying, succeeds

    it "should support event hooks without retry" do
      $hooked_fail_count = 0
      clear_jobs!('foo.bar.events')
      out = silenced(2) do
        HookedObjectSuccess.async(:queue => 'foo.bar.events').foo(5)
        worker = @worker_class.new('foo.bar.events')
        worker.prepare
        worker.work_one_job
      end
      assert_match /before_enqueue.*after_enqueue.*Working 1 queues/m, out
      assert_match /!!before_enqueue_bar!! \[nil, :foo, 5\]/, out
      assert_match /!!after_enqueue_bar!! \[nil, :foo, 5\]/, out
      assert_match /!!before_perform_foo!! \[nil, "foo", 5\]/, out
      assert_match /!!BEGIN around_perform_bar!! \[nil, "foo", 5\]/, out
      assert_match /!!BEGIN around_perform_cat!! \[nil, "foo", 5\]/, out
      assert_match /!!on_failure_foo!!.*HookFailError/, out
      assert_match /attempt 1 of 1, burying/, out
    end # event hooks, no retry

    it "should support event hooks with retry" do
      $hooked_fail_count = 0
      clear_jobs!('foo.bar.events.retry')
      Backburner.configure { |config| config.max_job_retries = 1; config.retry_delay = 0 }
      out = silenced(2) do
        HookedObjectSuccess.async(:queue => 'foo.bar.events.retry').foo(5)
        worker = @worker_class.new('foo.bar.events.retry')
        worker.prepare
        2.times do
          worker.work_one_job
        end
      end
      assert_match /before_enqueue.*after_enqueue.*Working 1 queues/m, out
      assert_match /!!before_enqueue_bar!! \[nil, :foo, 5\]/, out
      assert_match /!!after_enqueue_bar!! \[nil, :foo, 5\]/, out
      assert_match /!!before_perform_foo!! \[nil, "foo", 5\]/, out
      assert_match /!!BEGIN around_perform_bar!! \[nil, "foo", 5\]/, out
      assert_match /!!BEGIN around_perform_cat!! \[nil, "foo", 5\]/, out
      assert_match /!!on_failure_foo!!.*HookFailError/, out
      assert_match /!!on_failure_foo!!.*retrying.*around_perform_bar.*around_perform_cat/m, out
      assert_match /attempt 1 of 2, retrying/, out
      assert_match /!!before_perform_foo!! \[nil, "foo", 5\]/, out
      assert_match /!!END around_perform_bar!! \[nil, "foo", 5\]/, out
      assert_match /!!END around_perform_cat!! \[nil, "foo", 5\]/, out
      assert_match /!!after_perform_foo!! \[nil, "foo", 5\]/, out
      assert_match /Finished HookedObjectSuccess/, out
    end # event hooks, with retry

    it "should support event hooks with stopping enqueue" do
      $hooked_fail_count = 0
      clear_jobs!('foo.bar.events.retry2')
      out = silenced(2) do
        HookedObjectBeforeEnqueueFail.async(:queue => 'foo.bar.events.retry2').foo(5)
      end
      expanded_tube = [Backburner.configuration.tube_namespace, 'foo.bar.events.retry2'].join(".")
      assert_nil @worker_class.connection.tubes[expanded_tube].peek(:ready)
    end # stopping enqueue

    it "should support event hooks with stopping perform" do
      $hooked_fail_count = 0
      clear_jobs!('foo.bar.events.retry3')
      expanded_tube = [Backburner.configuration.tube_namespace, 'foo.bar.events.retry3'].join(".")
      out = silenced(2) do
        HookedObjectBeforePerformFail.async(:queue => 'foo.bar.events.retry3').foo(10)
        worker = @worker_class.new('foo.bar.events.retry3')
        worker.prepare
        worker.work_one_job
      end
      assert_match /!!before_perform_foo!! \[nil, "foo", 10\]/, out
      assert_match /before_perform_foo.*Completed/m, out
      refute_match(/Fail ran!!/, out)
      refute_match(/HookFailError/, out)
    end # stopping perform

    after do
      Backburner.configure { |config| config.max_job_retries = 0; config.retry_delay = 5 }
    end
  end # work_one_job
end # Worker