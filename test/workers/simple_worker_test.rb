require File.expand_path('../../test_helper', __FILE__)
require File.expand_path('../../fixtures/test_jobs', __FILE__)
require File.expand_path('../../fixtures/hooked', __FILE__)

describe "Backburner::Workers::Simple module" do
  before do
    Backburner.default_queues.clear
    @worker_class = Backburner::Workers::Simple
  end

  describe "for prepare method" do
    it "should make tube names array always unique to avoid duplication" do
      worker = @worker_class.new(["foo", "demo.test.foo"])
      capture_stdout { worker.prepare }
      assert_equal ["demo.test.foo"], worker.tube_names
    end

    it "should watch specified tubes" do
      worker = @worker_class.new(["foo", "bar"])
      out = capture_stdout { worker.prepare }
      assert_equal ["demo.test.foo", "demo.test.bar"], worker.tube_names
      assert_same_elements ["demo.test.foo", "demo.test.bar"], worker.connection.tubes.watched.map(&:name)
      assert_match(/demo\.test\.foo/, out)
    end # multiple

    it "should watch single tube" do
      worker = @worker_class.new("foo")
      out = capture_stdout { worker.prepare }
      assert_equal ["demo.test.foo"], worker.tube_names
      assert_same_elements ["demo.test.foo"], worker.connection.tubes.watched.map(&:name)
      assert_match(/demo\.test\.foo/, out)
    end # single

    it "should respect default_queues settings" do
      Backburner.default_queues.concat(["foo", "bar"])
      worker = @worker_class.new
      out = capture_stdout { worker.prepare }
      assert_equal ["demo.test.foo", "demo.test.bar"], worker.tube_names
      assert_same_elements ["demo.test.foo", "demo.test.bar"], worker.connection.tubes.watched.map(&:name)
      assert_match(/demo\.test\.foo/, out)
    end

    it "should assign based on all tubes" do
      @worker_class.any_instance.expects(:all_existing_queues).once.returns("bar")
      worker = @worker_class.new
      out = capture_stdout { worker.prepare }
      assert_equal ["demo.test.bar"], worker.tube_names
      assert_same_elements ["demo.test.bar"], worker.connection.tubes.watched.map(&:name)
      assert_match(/demo\.test\.bar/, out)
    end # all assign

    it "should properly retrieve all tubes" do
      worker = @worker_class.new
      out = capture_stdout { worker.prepare }
      assert_contains worker.tube_names, "demo.test.backburner-jobs"
      assert_contains worker.connection.tubes.watched.map(&:name), "demo.test.backburner-jobs"
      assert_match(/demo\.test\.backburner-jobs/, out)
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
      # NB: The #bury expectation below leaves the job in the queue (as reserved!)
      # since bury is never actually called on the task. Therefore, clear_jobs!()
      # can't remove it which can break a lot of things depending on the order the
      # tests are run. So we ensure that it's using a unique queue name. Mocha
      # lacks expectations with proxies (where we could actually call bury)
      clear_jobs!('foo.bar.failed')
      @worker_class.enqueue TestFailJob, [1, 2], :queue => 'foo.bar.failed'
      Backburner::Job.any_instance.expects(:bury).once
      out = silenced(2) do
        worker = @worker_class.new('foo.bar.failed')
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
      assert_match(/attempt 1 of 2, retrying/, out.first)
      assert_match(/Finished TestRetryJob/m, out.last)
      assert_match(/attempt 2 of 2, burying/m, out.last)
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
      assert_match(/attempt 1 of 3, retrying/, out.first)
      assert_match(/attempt 2 of 3, retrying/, out[1])
      assert_match(/Completed TestRetryJob/m, out.last)
      refute_match(/failed/, out.last)
      assert_equal 3, $worker_test_count
      assert_equal true, $worker_success
    end # retrying, succeeds

    it "should back off retries exponentially" do
      max_job_retries = 3
      clear_jobs!('foo.bar')
      Backburner.configure do |config|
        config.max_job_retries = max_job_retries
        config.retry_delay = 0
        #config.retry_delay_proc = lambda { |min_retry_delay, num_retries| min_retry_delay + (num_retries ** 3) } # default retry_delay_proc
      end
      @worker_class.enqueue TestConfigurableRetryJob, [max_job_retries], :queue => 'foo.bar'
      out = []
      (max_job_retries + 1).times do
        out << silenced(10) do
          worker = @worker_class.new('foo.bar')
          worker.prepare
          worker.work_one_job
        end
      end
      assert_match(/attempt 1 of 4, retrying in 0/, out.first)
      assert_match(/attempt 2 of 4, retrying in 1/, out[1])
      assert_match(/attempt 3 of 4, retrying in 8/, out[2])
      assert_match(/Completed TestConfigurableRetryJob/m, out.last)
      refute_match(/failed/, out.last)
      assert_equal 4, $worker_test_count
      assert_equal true, $worker_success
    end

    it "should allow configurable back off retry delays" do
      max_job_retries = 3
      clear_jobs!('foo.bar')
      Backburner.configure do |config|
        config.max_job_retries = max_job_retries
        config.retry_delay = 0
        config.retry_delay_proc = lambda { |min_retry_delay, num_retries| min_retry_delay + (num_retries ** 2) }
      end
      @worker_class.enqueue TestConfigurableRetryJob, [max_job_retries], :queue => 'foo.bar'
      out = []
      (max_job_retries + 1).times do
        out << silenced(5) do
          worker = @worker_class.new('foo.bar')
          worker.prepare
          worker.work_one_job
        end
      end
      assert_match(/attempt 1 of 4, retrying in 0/, out.first)
      assert_match(/attempt 2 of 4, retrying in 1/, out[1])
      assert_match(/attempt 3 of 4, retrying in 4/, out[2])
      assert_match(/Completed TestConfigurableRetryJob/m, out.last)
      refute_match(/failed/, out.last)
      assert_equal 4, $worker_test_count
      assert_equal true, $worker_success
    end

    it "should allow queue override of retries" do
      max_job_retries = TestRetryWithQueueOverridesJob.queue_max_job_retries
      clear_jobs!('foo.bar')
      Backburner.configure do |config|
         # Config should be overridden by queue overrides
        config.max_job_retries = 20
        config.retry_delay = 60
        #config.retry_delay_proc = lambda { |min_retry_delay, num_retries| min_retry_delay + (num_retries ** 3) } # default retry_delay_proc
      end
      @worker_class.enqueue TestRetryWithQueueOverridesJob, [max_job_retries], :queue => 'foo.bar'
      out = []
      (max_job_retries + 1).times do
        out << silenced(5) do
          worker = @worker_class.new('foo.bar')
          worker.prepare
          worker.work_one_job
        end
      end
      assert_match(/attempt 1 of 4, retrying in 0/, out.first)
      assert_match(/attempt 2 of 4, retrying in 1/, out[1])
      assert_match(/attempt 3 of 4, retrying in 4/, out[2])
      assert_match(/Completed TestRetryWithQueueOverridesJob/m, out.last)
      refute_match(/failed/, out.last)
      assert_equal 4, $worker_test_count
      assert_equal true, $worker_success
    end

    it "should support event hooks without retry" do
      $hooked_fail_count = 0
      clear_jobs!('foo.bar.events')
      out = silenced(2) do
        HookedObjectSuccess.async(:queue => 'foo.bar.events').foo(5)
        worker = @worker_class.new('foo.bar.events')
        worker.prepare
        worker.work_one_job
      end
      assert_match(/before_enqueue.*after_enqueue.*Working 1 queues/m, out)
      assert_match(/!!before_enqueue_bar!! \[nil, :foo, 5\]/, out)
      assert_match(/!!after_enqueue_bar!! \[nil, :foo, 5\]/, out)
      assert_match(/!!before_perform_foo!! \[nil, "foo", 5\]/, out)
      assert_match(/!!BEGIN around_perform_bar!! \[nil, "foo", 5\]/, out)
      assert_match(/!!BEGIN around_perform_cat!! \[nil, "foo", 5\]/, out)
      assert_match(/!!on_failure_foo!!.*HookFailError/, out)
      assert_match(/!!on_bury_foo!! \[nil, "foo", 5\]/, out)
      assert_match(/attempt 1 of 1, burying/, out)
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
      assert_match(/before_enqueue.*after_enqueue.*Working 1 queues/m, out)
      assert_match(/!!before_enqueue_bar!! \[nil, :foo, 5\]/, out)
      assert_match(/!!after_enqueue_bar!! \[nil, :foo, 5\]/, out)
      assert_match(/!!before_perform_foo!! \[nil, "foo", 5\]/, out)
      assert_match(/!!BEGIN around_perform_bar!! \[nil, "foo", 5\]/, out)
      assert_match(/!!BEGIN around_perform_cat!! \[nil, "foo", 5\]/, out)
      assert_match(/!!on_failure_foo!!.*HookFailError/, out)
      assert_match(/!!on_failure_foo!!.*retrying.*around_perform_bar.*around_perform_cat/m, out)
      assert_match(/!!on_retry_foo!! 1 0 \[nil, "foo", 5\]/, out)
      assert_match(/attempt 1 of 2, retrying/, out)
      assert_match(/!!before_perform_foo!! \[nil, "foo", 5\]/, out)
      assert_match(/!!END around_perform_bar!! \[nil, "foo", 5\]/, out)
      assert_match(/!!END around_perform_cat!! \[nil, "foo", 5\]/, out)
      assert_match(/!!after_perform_foo!! \[nil, "foo", 5\]/, out)
      assert_match(/Finished HookedObjectSuccess/, out)
    end # event hooks, with retry

    it "should support event hooks with stopping enqueue" do
      $hooked_fail_count = 0
      worker = @worker_class.new('foo.bar.events.retry2')
      clear_jobs!('foo.bar.events.retry2')
      silenced(2) do
        HookedObjectBeforeEnqueueFail.async(:queue => 'foo.bar.events.retry2').foo(5)
      end
      expanded_tube = [Backburner.configuration.tube_namespace, 'foo.bar.events.retry2'].join(".")
      assert_nil worker.connection.tubes[expanded_tube].peek(:ready)
    end # stopping enqueue

    it "should support event hooks with stopping perform" do
      $hooked_fail_count = 0
      clear_jobs!('foo.bar.events.retry3')
      [Backburner.configuration.tube_namespace, 'foo.bar.events.retry3'].join(".")
      out = silenced(2) do
        HookedObjectBeforePerformFail.async(:queue => 'foo.bar.events.retry3').foo(10)
        worker = @worker_class.new('foo.bar.events.retry3')
        worker.prepare
        worker.work_one_job
      end
      assert_match(/!!before_perform_foo!! \[nil, "foo", 10\]/, out)
      assert_match(/before_perform_foo.*Completed/m, out)
      refute_match(/Fail ran!!/, out)
      refute_match(/HookFailError/, out)
    end # stopping perform

    it "should delete a job whose before_perform hook stopped it" do
      clear_jobs!('foo.bar.events.retry3')
      worker = @worker_class.new('foo.bar.events.retry3')
      silenced(2) do
        HookedObjectBeforePerformFail.async(:queue => 'foo.bar.events.retry3').foo(10)
        worker.prepare
        worker.work_one_job
      end
      stats = worker.connection.tubes['demo.test.foo.bar.events.retry3'].stats
      assert_equal 0, stats.current_jobs_reserved, "the aborted job is still reserved"
      assert_equal 0, stats.current_jobs_ready + stats.current_jobs_delayed + stats.current_jobs_buried
    end # stopping perform deletes

    it "should keep working when the TTR ran out before the job could be buried" do
      clear_jobs!("foo.bar.ttr")
      @worker_class.enqueue TestOverTTRJob, [], :queue => "foo.bar.ttr"
      worker = @worker_class.new('foo.bar.ttr')
      out = silenced(6) do
        worker.prepare
        worker.work_one_job
      end
      assert_match(/TestOverTTRJob.* hit 1s timeout/, out)
      assert_match(/TestOverTTRJob was no longer reserved/, out)
      # beanstalkd took the job back when its TTR ran out and hands it out again
      pop_one_job("foo.bar.ttr") { |job, body| assert_equal "TestOverTTRJob", body["class"]; job.delete }
    end

    it "should keep working when the TTR ran out before the job could be retried" do
      Backburner.configure { |config| config.max_job_retries = 1; config.retry_delay = 0 }
      clear_jobs!("foo.bar.ttr")
      @worker_class.enqueue TestOverTTRJob, [], :queue => "foo.bar.ttr"
      worker = @worker_class.new('foo.bar.ttr')
      out = silenced(6) do
        worker.prepare
        worker.work_one_job
      end
      assert_match(/TestOverTTRJob was no longer reserved/, out)
      pop_one_job("foo.bar.ttr") { |job, body| assert_equal "TestOverTTRJob", body["class"]; job.delete }
    end

    it "should keep working when the connection is lost before the failed job could be retried or buried" do
      clear_jobs!("foo.bar.lost")
      @worker_class.enqueue TestFailJob, [1, 2], :queue => "foo.bar.lost"
      worker = @worker_class.new('foo.bar.lost')
      errors = []
      Backburner.configure { |config| config.on_error = lambda { |e| errors << e } }
      # beanstalkd went away while the job ran: asking for its stats (to retry or bury it)
      # raises NotConnected
      Beaneater::Job.any_instance.stubs(:ttr).returns(10)
      Beaneater::Job.any_instance.stubs(:stats).raises(Beaneater::NotConnected)
      out = silenced(2) do
        worker.prepare
        worker.work_one_job
      end
      assert_match(/TestFailJob was no longer reserved/, out)
      assert_equal [RuntimeError], errors.map(&:class)
    ensure
      Beaneater::Job.any_instance.unstub(:stats)
      Beaneater::Job.any_instance.unstub(:ttr)
      Backburner.configure { |config| config.on_error = nil }
    end

    describe "with a job whose class can't be found" do
      before do
        clear_jobs!("foo.bar.unknown")
        @errors = []
        Backburner.configure { |config| config.on_error = lambda { |e| @errors << e } }
        @worker = @worker_class.new('foo.bar.unknown')
      end

      after do
        Backburner.configure { |config| config.on_error = nil }
        clear_jobs!("foo.bar.unknown")
      end

      def put_job(class_name, ttr)
        body = Backburner.configuration.job_serializer_proc.call(:class => class_name, :args => [1])
        @worker.connection.tubes["demo.test.foo.bar.unknown"].put(body, :ttr => ttr)
      end

      def tube_stats
        @worker.connection.tubes["demo.test.foo.bar.unknown"].stats
      end

      it "should release it for its TTR instead of burying it, and keep working" do
        put_job("TestRemovedJob", 100)
        out = silenced(2) do
          @worker.prepare
          @worker.work_one_job
        end
        assert_match(/Exception Backburner::Job::JobNotFound -> TestRemovedJob/, out)
        assert_match(/TestRemovedJob: class not found; released for 100s/, out)
        assert_equal [], @errors, "on_error isn't called for a class this worker lacks"
        assert_equal 0, tube_stats.current_jobs_buried
        assert_equal 1, tube_stats.current_jobs_delayed
        assert_equal 100, @worker.connection.tubes["demo.test.foo.bar.unknown"].peek(:delayed).stats.delay
      end

      it "should leave it for a worker that has its class, however many retries it is allowed" do
        Backburner.configure { |config| config.max_job_retries = 0 }
        put_job("TestRolloutJob", 2)
        out = silenced(8) do
          @worker.prepare
          @worker.work_one_job # this worker doesn't have the class yet
          Object.const_set(:TestRolloutJob, Class.new { def self.perform(x); $worker_test_count += x; end })
          @worker.work_one_job # now it does: the job comes back after its TTR
        end
        assert_match(/TestRolloutJob: class not found; released for 2s/, out)
        assert_match(/Completed TestRolloutJob/, out)
        assert_equal 1, $worker_test_count
        assert_equal 0, tube_stats.current_jobs_buried
      ensure
        Object.send(:remove_const, :TestRolloutJob) if Object.const_defined?(:TestRolloutJob)
      end

      it "should release a job whose class an autoloader can't load" do
        put_job("AutoloadingDemo::TestJobGone", 100)
        out = silenced(2) do
          @worker.prepare
          @worker.work_one_job
        end
        assert_match(/AutoloadingDemo::TestJobGone: class not found; released for 100s/, out)
        assert_equal [0, 1], [tube_stats.current_jobs_buried, tube_stats.current_jobs_delayed]
      end
    end # unknown class

    it "should keep working when the on_error handler raises" do
      clear_jobs!("foo.bar.onerror")
      Backburner.configure { |config| config.on_error = lambda { |e| raise SocketError, "error reporter unreachable" } }
      @worker_class.enqueue TestFailJob, [1, 2], :queue => "foo.bar.onerror"
      @worker_class.enqueue TestJob, [1, 2], :queue => "foo.bar.onerror"
      worker = @worker_class.new('foo.bar.onerror')
      out = silenced(4) do
        worker.prepare
        2.times { worker.work_one_job }
      end
      assert_match(/Finished TestFailJob.*attempt 1 of 1, burying/, out)
      assert_match(/The on_error handler failed for TestFailJob: Exception SocketError -> error reporter unreachable/, out)
      assert_equal 1, worker.connection.tubes["demo.test.foo.bar.onerror"].stats.current_jobs_buried
      assert_equal 3, $worker_test_count
    ensure
      Backburner.configure { |config| config.on_error = nil }
      clear_jobs!("foo.bar.onerror")
    end

    it "should use the connection given as an argument" do
      worker = @worker_class.new('foo.bar')
      connection = mock('connection')
      worker.expects(:reserve_job).with(connection).returns(stub_everything('job'))
      capture_stdout { worker.work_one_job(connection) }
    end

    after do
      Backburner.configure do |config|
        config.max_job_retries = 0
        config.retry_delay = 5
        config.retry_delay_proc = lambda { |min_retry_delay, num_retries| min_retry_delay + (num_retries ** 3) }
      end
    end
  end # work_one_job

  describe "when beanstalkd is down for longer than the reconnect window" do
    before do
      pick_beanstalkd_port
      @templogger = Templogger.new('/tmp')
      @beanstalk_url = Backburner.configuration.beanstalk_url
      Backburner.configure do |config|
        config.beanstalk_url = "beanstalk://127.0.0.1:#{@port}"
        config.logger = @templogger.logger
      end
      start_beanstalkd
      $worker_test_count = 0
    end

    after do
      @worker_thread.kill if @worker_thread
      stop_beanstalkd
      if @templogger
        Backburner.configure do |config|
          config.beanstalk_url = @beanstalk_url
          config.logger = nil
        end
        @templogger.close
      end
    end

    it "should reconnect, watch its tubes again and resume working" do
      worker = @worker_class.new('foo.bar.outage')
      worker.prepare
      @worker_thread = Thread.new { loop { worker.work_one_job } }
      sleep 0.5 # let the worker block in reserve

      stop_beanstalkd
      # beaneater's own reconnect attempts fail, then Connection#ensure_connected! gives up too
      wait_for { @templogger.body.scan(/Exception Beaneater::NotConnected/).size >= 2 }
      start_beanstalkd
      @worker_class.enqueue TestJob, [1, 2], :queue => 'foo.bar.outage'
      wait_for(10) { $worker_test_count == 3 }

      errors = @templogger.body.scan(/ERROR -- /).size
      assert_operator errors, :<, 20, "the worker logged #{errors} errors (busy loop?)"
      assert_equal 3, $worker_test_count
    end
  end # beanstalkd outage
end # Worker
