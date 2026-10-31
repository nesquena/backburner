require File.expand_path('../test_helper', __FILE__)
require File.expand_path('../fixtures/test_jobs', __FILE__)
require File.expand_path('../fixtures/hooked', __FILE__)

describe "Backburner::Worker module" do
  before do
    Backburner.default_queues.clear
    clear_jobs!(Backburner.configuration.primary_queue, "test-plain", "test.bar", "bar.baz.foo", "test-parent")
  end

  describe "for enqueue class method" do
    it "should support enqueuing plain job" do
      Backburner::Worker.enqueue TestPlainJob, [7, 9], :ttr => 100, :pri => 2000
      pop_one_job("test-plain") do |job, body|
        assert_equal "TestPlainJob", body["class"]
        assert_equal [7, 9], body["args"]
        assert_equal 100, job.ttr
        assert_equal 2000, job.pri
      end
    end # plain

    it "should support enqueuing job with class queue priority" do
      Backburner::Worker.enqueue TestJob, [3, 4], :ttr => 100
      pop_one_job do |job, body|
        assert_equal "TestJob", body["class"]
        assert_equal [3, 4], body["args"]
        assert_equal 100, job.ttr
        assert_equal 100, job.pri
      end
    end # queue priority

    it "should support enqueuing job with specified named priority" do
      Backburner::Worker.enqueue TestJob, [3, 4], :ttr => 100, :pri => 'high'
      pop_one_job do |job, body|
        assert_equal "TestJob", body["class"]
        assert_equal [3, 4], body["args"]
        assert_equal 100, job.ttr
        assert_equal 0, job.pri
      end
    end # queue named priority

    it "should support enqueuing job with class queue respond_timeout" do
      Backburner::Worker.enqueue TestJob, [3, 4]
      pop_one_job do |job, body|
        assert_equal "TestJob", body["class"]
        assert_equal [3, 4], body["args"]
        assert_equal 300, job.ttr
        assert_equal 100, job.pri
      end
    end # queue respond_timeout

    it "should enqueue a subclass job on its superclass queue with its settings" do
      Backburner::Worker.enqueue TestChildQueueJob, [3, 4]
      pop_one_job("test-parent") do |job, body|
        assert_equal "TestChildQueueJob", body["class"]
        assert_equal [3, 4], body["args"]
        assert_equal 250, job.ttr
        assert_equal 0, job.pri
      end
    end # subclass queue

    it "should support a priority label as the default priority" do
      default_priority = Backburner.configuration.default_priority
      Backburner.configuration.default_priority = :low
      Backburner::Worker.enqueue TestPlainJob, [1, 2]
      pop_one_job("test-plain") do |job, body|
        assert_equal "TestPlainJob", body["class"]
        assert_equal 200, job.pri
      end
    ensure
      Backburner.configuration.default_priority = default_priority
    end # default priority label

    it "should support enqueuing job with custom queue" do
      Backburner::Worker.enqueue TestJob, [6, 7], :queue => "test.bar", :pri => 5000
      pop_one_job("test.bar") do |job, body|
        assert_equal "TestJob", body["class"]
        assert_equal [6, 7], body["args"]
        assert_equal 0, job.delay
        assert_equal 5000, job.pri
        assert_equal 300, job.ttr
      end
    end # custom

    it "should round a fractional delay up to whole seconds, so the job never runs early" do
      conn = beanstalk_connection
      { nil => 0, -1 => 0, 0 => 0, 0.2 => 1, 1 => 1, 1.5 => 2, 2 => 2 }.each do |delay, expected|
        response = Backburner::Worker.enqueue TestPlainJob, [1, 2], :delay => delay
        assert_equal expected, conn.jobs.find(response[:id]).stats.delay, "delay #{delay.inspect}"
      end
    ensure
      conn.close if conn
      clear_jobs!("test-plain")
    end # fractional delay

    it "should round a fractional TTR up to whole seconds, from an option, a class or the default" do
      respond_timeout = Backburner.configuration.respond_timeout
      conn = beanstalk_connection
      ttr_of = lambda { |response| conn.jobs.find(response[:id]).stats.ttr }
      assert_equal 1, ttr_of.call(Backburner::Worker.enqueue(TestPlainJob, [1, 2], :ttr => 0.2))
      assert_equal 2, ttr_of.call(Backburner::Worker.enqueue(TestFloatRespondTimeoutJob, []))
      Backburner.configuration.respond_timeout = 2.5
      assert_equal 3, ttr_of.call(Backburner::Worker.enqueue(TestPlainJob, [1, 2]))
    ensure
      Backburner.configuration.respond_timeout = respond_timeout
      conn.close if conn
      clear_jobs!("test-plain")
    end # fractional ttr

    it "should support async job" do
      TestAsyncJob.async(:ttr => 100, :queue => "bar.baz.foo").foo(10, 5)
      pop_one_job("bar.baz.foo") do |job, body|
        assert_equal "TestAsyncJob", body["class"]
        assert_equal [nil, "foo", 10, 5], body["args"]
        assert_equal 100, job.ttr
        assert_equal Backburner.configuration.default_priority, job.pri
      end
    end # async

    it "should support enqueueing job with lambda queue" do
      expected_queue_name = TestLambdaQueueJob.calculated_queue_name
      Backburner::Worker.enqueue TestLambdaQueueJob, [6, 7], :queue => lambda { |klass| klass.calculated_queue_name }
      pop_one_job(expected_queue_name) do |job, body|
        assert_equal "TestLambdaQueueJob", body["class"]
        assert_equal [6, 7], body["args"]
      end
    end
  end # enqueue

  describe "for the enqueue connections" do
    before do
      GC.start # closes the connections earlier tests left to the garbage collector before a test counts them
      @gc_was_disabled = GC.disable # and keeps a collection from closing one while it counts
      @stats_connection = beanstalk_connection
      @beanstalk_url = Backburner.configuration.beanstalk_url
    end

    after do
      GC.enable unless @gc_was_disabled
      @stats_connection.close
      Backburner.configuration.beanstalk_url = @beanstalk_url
    end

    # Connections beanstalkd has accepted so far
    def total_connections
      @stats_connection.stats.total_connections
    end

    def open_connections
      @stats_connection.stats.current_connections
    end

    def enqueue(n = 0)
      Backburner::Worker.enqueue(TestJob, [n, 0])
    end

    # Starts the pool afresh: a new URL (spelling the same beanstalkd) closes its idle connections.
    # Leaves one idle connection in it.
    def fresh_pool
      ["beanstalk://127.0.0.1:11300", "beanstalk://127.0.0.1:11300/"].each do |url|
        Backburner.configuration.beanstalk_url = url
        enqueue
      end
      settle
    end

    # Waits for beanstalkd to have seen the connections closed so far
    def settle
      last = nil
      wait_for(5) { (now = open_connections) == last || (last = now; sleep 0.1; false) }
    end

    it "should reuse a connection for sequential enqueues" do
      enqueue
      before_count = total_connections
      responses = Array.new(5) { |i| enqueue(i) }
      assert_equal ["INSERTED"] * 5, responses.map { |res| res[:status] }
      assert_equal 0, total_connections - before_count
    end

    it "should reuse a connection across fibers and threads" do
      enqueue
      before_count = total_connections
      5.times { |i| Fiber.new { enqueue(i) }.resume }
      5.times { |i| Thread.new { enqueue(i) }.join }
      assert_equal 0, total_connections - before_count
    end

    it "should keep at most 5 idle connections after concurrent enqueues" do
      fresh_pool # one idle connection
      before_total, before_open = total_connections, open_connections
      threads, inside = 8, Queue.new
      release = Queue.new
      serializer = Backburner.configuration.job_serializer_proc
      # every thread holds a connection until all of them do
      Backburner.configuration.job_serializer_proc = lambda { |body| inside << 1; release.pop; body.to_json }
      workers = Array.new(threads) { |i| Thread.new { enqueue(i) } }
      threads.times { inside.pop }
      threads.times { release << 1 }
      workers.each(&:join)
      Backburner.configuration.job_serializer_proc = serializer
      assert_equal threads - 1, total_connections - before_total, "one reused, the rest opened"
      kept = 5
      wait_for(5) { open_connections - before_open == kept - 1 }
      assert_equal kept - 1, open_connections - before_open, "only #{kept} stay open"
    ensure
      Backburner.configuration.job_serializer_proc = serializer if serializer
    end

    it "should give a forked child its own connection" do
      skip "needs fork" unless Process.respond_to?(:fork)
      enqueue(1)
      before_child = total_connections
      pid = Process.fork do
        res = Backburner::Worker.enqueue(TestJob, [2, 0]) rescue nil
        exit!(res && res[:status] == "INSERTED" ? 0 : 1)
      end
      Process.wait(pid)
      assert_equal 0, $?.exitstatus, "the child's enqueue failed"
      assert_equal 1, total_connections - before_child, "the child should open its own connection"
      assert_equal "INSERTED", enqueue(3)[:status]
      assert_equal 1, total_connections - before_child, "the parent should keep its connection"
    end

    it "should close a connection that an error interrupted instead of reusing it" do
      fresh_pool # one idle connection
      before_total, before_open = total_connections, open_connections
      serializer = Backburner.configuration.job_serializer_proc
      Backburner.configuration.job_serializer_proc = lambda { |body| raise Timeout::Error }
      assert_raises(Timeout::Error) { enqueue(2) }
      Backburner.configuration.job_serializer_proc = serializer
      wait_for(5) { open_connections == before_open - 1 }
      assert_equal before_open - 1, open_connections, "the interrupted connection should be closed"
      assert_equal "INSERTED", enqueue(3)[:status]
      assert_equal 1, total_connections - before_total, "the next enqueue should open a new connection"
    ensure
      Backburner.configuration.job_serializer_proc = serializer if serializer
    end

    it "should close a connection whose enqueue was killed" do
      fresh_pool # one idle connection
      before_total, before_open = total_connections, open_connections
      serializer = Backburner.configuration.job_serializer_proc
      inside = Queue.new
      Backburner.configuration.job_serializer_proc = lambda { |body| inside << 1; sleep }
      thread = Thread.new { enqueue(2) }
      inside.pop
      thread.kill.join
      Backburner.configuration.job_serializer_proc = serializer
      wait_for(5) { open_connections == before_open - 1 }
      assert_equal before_open - 1, open_connections, "the killed enqueue's connection should be closed"
      assert_equal "INSERTED", enqueue(3)[:status]
      assert_equal 1, total_connections - before_total, "the next enqueue should open a new connection"
    ensure
      Backburner.configuration.job_serializer_proc = serializer if serializer
    end

    it "should replace a connection idle for longer than enqueue_connection_max_idle" do
      max_idle = Backburner.configuration.enqueue_connection_max_idle
      fresh_pool # one idle connection
      before_total, before_open = total_connections, open_connections
      Backburner.configuration.enqueue_connection_max_idle = 0.05
      sleep 0.1
      assert_equal "INSERTED", enqueue(1)[:status]
      assert_equal 1, total_connections - before_total, "the expired connection should be replaced"
      wait_for(5) { open_connections == before_open }
      assert_equal before_open, open_connections, "the expired connection should be closed"
      Backburner.configuration.enqueue_connection_max_idle = 60
      assert_equal "INSERTED", enqueue(2)[:status]
      assert_equal 1, total_connections - before_total, "a fresh connection should be reused"
    ensure
      Backburner.configuration.enqueue_connection_max_idle = max_idle
    end

    describe "when beanstalkd goes away" do
      before do
        pick_beanstalkd_port
        @beanstalk_url = Backburner.configuration.beanstalk_url
        Backburner.configuration.beanstalk_url = "beanstalk://127.0.0.1:#{@port}"
        start_beanstalkd
      end

      after do
        stop_beanstalkd
        Backburner.configuration.beanstalk_url = @beanstalk_url if @beanstalk_url
      end

      it "should recover from a restart and from Beaneater::NotConnected" do
        Thread.new do
          assert_equal "INSERTED", Backburner::Worker.enqueue(TestJob, [1, 0])[:status]
          stop_beanstalkd
          start_beanstalkd
          assert_equal "INSERTED", Backburner::Worker.enqueue(TestJob, [2, 0])[:status]
          stop_beanstalkd
          assert_raises(Beaneater::NotConnected) { Backburner::Worker.enqueue(TestJob, [3, 0]) }
          start_beanstalkd
          assert_equal "INSERTED", Backburner::Worker.enqueue(TestJob, [4, 0])[:status]
        end.join
      end
    end # beanstalkd goes away
  end # enqueue connection

  describe "without a tube_namespace" do
    before { @tube_namespace = Backburner.configuration.tube_namespace }
    after { Backburner.configuration.tube_namespace = @tube_namespace }

    def reserve_from(tube_name)
      connection = beanstalk_connection
      connection.tubes.watch!(tube_name)
      job = connection.tubes.reserve(1)
      job.delete
      Backburner.configuration.job_parser_proc.call(job.body)
    ensure
      connection.close if connection
    end

    it "should enqueue on unprefixed tubes when tube_namespace is nil, false or empty" do
      [nil, false, ""].each do |namespace|
        Backburner.configuration.tube_namespace = namespace
        Backburner::Worker.enqueue TestJob, [1, namespace.inspect]
        Backburner::Worker.enqueue TestJob, [2, namespace.inspect], :queue => "test-no-namespace"
        assert_equal [1, namespace.inspect], reserve_from("backburner-jobs")["args"]
        assert_equal [2, namespace.inspect], reserve_from("test-no-namespace")["args"]
      end
    end

    it "should list existing unprefixed tubes for a worker given no tubes" do
      Backburner.configuration.tube_namespace = false
      Backburner::Worker.enqueue TestJob, [1, 2], :queue => "test-no-namespace"
      assert_contains Backburner::Worker.new(nil).tube_names, "test-no-namespace"
      reserve_from("test-no-namespace")
    end
  end # without a tube_namespace

  describe "for start class method" do
    it "should initialize and start the worker instance" do
      ech = stub
      Backburner::Worker.expects(:new).with("foo").returns(ech)
      ech.expects(:start)
      Backburner::Worker.start("foo")
    end
  end # start

  describe "with an anonymous subclass of a queue class" do
    before { @anonymous = Class.new(TestNamedQueueJob) }
    after { Backburner::Worker.known_queue_classes.delete(@anonymous) }

    it "should leave it out of the known queues of a worker given no tubes" do
      [Backburner::Workers::Simple, Backburner::Workers::Threading, Backburner::Workers::ThreadsOnFork].each do |worker_class|
        assert_contains worker_class.new(nil).tube_names.map { |name| Backburner::Worker.expand_tube_name(name) },
          Backburner::Worker.expand_tube_name("testnamedqueuejob"), worker_class.name
      end
    end
  end # anonymous subclass

  describe "for tube_names accessor" do
    before do
      Backburner.default_queues << "baz"
      Backburner.default_queues << "bam"
    end

    it "supports retrieving tubes" do
      worker = Backburner::Worker.new(["foo", "bar"])
      assert_equal ["foo", "bar"], worker.tube_names
    end

    it "supports single tube array arg" do
      worker = Backburner::Worker.new([["foo", "bar"]])
      assert_equal ["foo", "bar"], worker.tube_names
    end

    it "supports empty nil array arg with default values" do
      worker = Backburner::Worker.new([nil])
      assert_equal ['baz', 'bam'], worker.tube_names
    end

    it "supports single tube arg" do
      worker = Backburner::Worker.new("foo")
      assert_equal ["foo"], worker.tube_names
    end

    it "supports empty array arg with default values" do
      worker = Backburner::Worker.new([])
      assert_equal ['baz', 'bam'], worker.tube_names
    end

    it "supports nil arg with default values" do
      worker = Backburner::Worker.new(nil)
      assert_equal ['baz', 'bam'], worker.tube_names
    end
  end # tube_names

  describe "for custom serialization" do
    before do
      Backburner.configure do |config|
        @old_parser = config.job_parser_proc
        @old_serializer = config.job_serializer_proc
        config.job_parser_proc = lambda { |body| Marshal.load(body) }
        config.job_serializer_proc = lambda { |body| Marshal.dump(body) }
      end
    end

    after do
      clear_jobs!('test-plain')
      Backburner.configure do |config|
        config.job_parser_proc = @old_parser
        config.job_serializer_proc = @old_serializer
      end
    end

    it "should support enqueuing a job" do
      Backburner::Worker.enqueue TestPlainJob, [7, 9], :ttr => 100, :pri => 2000
      pop_one_job("test-plain") do |job, body|
        assert_equal "TestPlainJob", body[:class]
        assert_equal [7, 9], body[:args]
        assert_equal 100, job.ttr
        assert_equal 2000, job.pri
      end
    end
  end # custom serialization
end # Backburner::Worker
