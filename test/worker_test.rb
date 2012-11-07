require File.expand_path('../test_helper', __FILE__)
require File.expand_path('../fixtures/test_jobs', __FILE__)
require File.expand_path('../fixtures/hooked', __FILE__)

describe "Backburner::Worker module" do
  before do
    Backburner.default_queues.clear
  end

  describe "for enqueue class method" do
    it "should support enqueuing job" do
      Backburner::Worker.enqueue TestJob, [3, 4], :ttr => 100
      job, body = pop_one_job("test-job")
      assert_equal "TestJob", body["class"]
      assert_equal [3, 4], body["args"]
      assert_equal 100, job.ttr
      assert_equal 1000, job.pri
    end # simple

    it "should support enqueuing job with custom queue" do
      Backburner::Worker.enqueue TestJob, [6, 7], :queue => "test.bar", :pri => 5000
      job, body = pop_one_job("test.bar")
      assert_equal "TestJob", body["class"]
      assert_equal [6, 7], body["args"]
      assert_equal 0, job.delay
      assert_equal 5000, job.pri
      assert_equal Backburner.configuration.respond_timeout, job.ttr
    end # custom

    it "should support async job" do
      TestAsyncJob.async(:ttr => 100, :queue => "bar.baz.foo").foo(10, 5)
      job, body = pop_one_job("bar.baz.foo")
      assert_equal "TestAsyncJob", body["class"]
      assert_equal [nil, "foo", 10, 5], body["args"]
      assert_equal 100, job.ttr
      assert_equal Backburner.configuration.default_priority, job.pri
    end # async
  end # enqueue

  describe "for start class method" do
    it "should initialize and start the worker instance" do
      ech = stub
      Backburner::Worker.expects(:new).with("foo").returns(ech)
      ech.expects(:start)
      Backburner::Worker.start("foo")
    end
  end # start

  describe "for connection class method" do
    it "should return the beanstalk connection" do
      assert_equal "beanstalk://localhost", Backburner::Worker.connection.url
      assert_kind_of Beaneater::Pool, Backburner::Worker.connection.beanstalk
    end
  end # connection

  describe "for tube_names accessor" do
    it "supports retrieving tubes" do
      worker = Backburner::Worker.new(["foo", "bar"])
      assert_equal ["foo", "bar"], worker.tube_names
    end

    it "supports single tube array arg" do
      worker = Backburner::Worker.new([["foo", "bar"]])
      assert_equal ["foo", "bar"], worker.tube_names
    end

    it "supports empty nil array arg" do
      worker = Backburner::Worker.new([nil])
      assert_equal nil, worker.tube_names
    end

    it "supports single tube arg" do
      worker = Backburner::Worker.new("foo")
      assert_equal ["foo"], worker.tube_names
    end

    it "supports empty array arg" do
      worker = Backburner::Worker.new([])
      assert_equal nil, worker.tube_names
    end

    it "supports nil arg" do
      worker = Backburner::Worker.new(nil)
      assert_equal nil, worker.tube_names
    end
  end # tube_names

  describe "for prepare method" do
    it "should watch specified tubes" do
      worker = Backburner::Worker.new(["foo", "bar"])
      out = capture_stdout { worker.prepare }
      assert_equal ["demo.test.foo", "demo.test.bar"], worker.tube_names
      assert_same_elements ["demo.test.foo", "demo.test.bar"], Backburner::Worker.connection.tubes.watched.map(&:name)
      assert_match /demo\.test\.foo/, out
    end # multiple

    it "should watch single tube" do
      worker = Backburner::Worker.new("foo")
      out = capture_stdout { worker.prepare }
      assert_equal ["demo.test.foo"], worker.tube_names
      assert_same_elements ["demo.test.foo"], Backburner::Worker.connection.tubes.watched.map(&:name)
      assert_match /demo\.test\.foo/, out
    end # single

    it "should respect default_queues settings" do
      Backburner.default_queues.concat(["foo", "bar"])
      worker = Backburner::Worker.new
      out = capture_stdout { worker.prepare }
      assert_equal ["demo.test.foo", "demo.test.bar"], worker.tube_names
      assert_same_elements ["demo.test.foo", "demo.test.bar"], Backburner::Worker.connection.tubes.watched.map(&:name)
      assert_match /demo\.test\.foo/, out
    end

    it "should assign based on all tubes" do
      Backburner::Worker.any_instance.expects(:all_existing_queues).once.returns("bar")
      worker = Backburner::Worker.new
      out = capture_stdout { worker.prepare }
      assert_equal ["demo.test.bar"], worker.tube_names
      assert_same_elements ["demo.test.bar"], Backburner::Worker.connection.tubes.watched.map(&:name)
      assert_match /demo\.test\.bar/, out
    end # all assign

    it "should properly retrieve all tubes" do
      worker = Backburner::Worker.new
      out = capture_stdout { worker.prepare }
      assert_contains worker.tube_names, "demo.test.test-job"
      assert_contains Backburner::Worker.connection.tubes.watched.map(&:name), "demo.test.test-job"
      assert_match /demo\.test\.test-job/, out
    end # all read
  end # prepare

  describe "for work_one_job method" do
    before do
      $worker_test_count = 0
      $worker_success = false
    end

    it "should work an enqueued job" do
      clear_jobs!("foo.bar")
      Backburner::Worker.enqueue TestJob, [1, 2], :queue => "foo.bar"
      silenced(2) do
        worker = Backburner::Worker.new('foo.bar')
        worker.prepare
        worker.work_one_job
      end
      assert_equal 3, $worker_test_count
    end # enqueue

    it "should fail quietly if there's an argument error" do
      clear_jobs!("foo.bar")
      Backburner::Worker.enqueue TestJob, ["bam", "foo", "bar"], :queue => "foo.bar"
      out = silenced(2) do
        worker = Backburner::Worker.new('foo.bar')
        worker.prepare
        worker.work_one_job
      end
      assert_match(/Exception ArgumentError/, out)
      assert_equal 0, $worker_test_count
    end # fail, argument

    it "should work an enqueued failing job" do
      clear_jobs!("foo.bar")
      Backburner::Worker.enqueue TestFailJob, [1, 2], :queue => "foo.bar"
      Backburner::Job.any_instance.expects(:bury).once
      out = silenced(2) do
        worker = Backburner::Worker.new('foo.bar')
        worker.prepare
        worker.work_one_job
      end
      assert_match(/Exception RuntimeError/, out)
      assert_equal 0, $worker_test_count
    end # fail, runtime error

    it "should work an invalid job parsed" do
      Beaneater::Tubes.any_instance.expects(:reserve).returns(stub(:body => "{%$^}", :bury => true))
      out = silenced(2) do
        worker = Backburner::Worker.new('foo.bar')
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
        worker = Backburner::Worker.new('foo.bar')
        worker.prepare
        worker.work_one_job
      end
      assert_equal 15, $worker_test_count
    end # async

    it "should support retrying jobs and burying" do
      clear_jobs!('foo.bar')
      Backburner.configure { |config| config.max_job_retries = 1; config.retry_delay = 0 }
      Backburner::Worker.enqueue TestRetryJob, ["bam", "foo"], :queue => 'foo.bar'
      out = []
      2.times do
        out << silenced(2) do
          worker = Backburner::Worker.new('foo.bar')
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
      Backburner::Worker.enqueue TestRetryJob, ["bam", "foo"], :queue => 'foo.bar'
      out = []
      3.times do
        out << silenced(2) do
          worker = Backburner::Worker.new('foo.bar')
          worker.prepare
          worker.work_one_job
        end
      end
      assert_match /attempt 1 of 3, retrying/, out.first
      assert_match /attempt 2 of 3, retrying/, out[1]
      assert_match /Finished TestRetryJob/m, out.last
      refute_match(/failed/, out.last)
      assert_equal 3, $worker_test_count
      assert_equal true, $worker_success
    end # retrying, succeeds

    it "should support event hooks without retry" do
      $hooked_fail_count = 0
      clear_jobs!('foo.bar.events')
      out = silenced(2) do
        HookedObjectSuccess.async(:queue => 'foo.bar.events').foo(5)
        worker = Backburner::Worker.new('foo.bar.events')
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
        worker = Backburner::Worker.new('foo.bar.events.retry')
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
      assert_nil Backburner::Worker.connection.tubes[expanded_tube].peek(:ready)
    end # stopping enqueue

    it "should support event hooks with stopping perform" do
      $hooked_fail_count = 0
      clear_jobs!('foo.bar.events.retry3')
      expanded_tube = [Backburner.configuration.tube_namespace, 'foo.bar.events.retry3'].join(".")
      out = silenced(2) do
        HookedObjectBeforePerformFail.async(:queue => 'foo.bar.events.retry3').foo(10)
        worker = Backburner::Worker.new('foo.bar.events.retry3')
        worker.prepare
        worker.work_one_job
      end
      assert_match /!!before_perform_foo!! \[nil, "foo", 10\]/, out
      assert_match /before_perform_foo.*Finished/m, out
      refute_match(/Fail ran!!/, out)
      refute_match(/HookFailError/, out)
    end # stopping perform

    after do
      Backburner.configure { |config| config.max_job_retries = 0; config.retry_delay = 5 }
    end
  end # work_one_job
end # Backburner::Worker