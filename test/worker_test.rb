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

  describe "for the enqueue connection" do
    before { @stats_connection = beanstalk_connection }
    after { @stats_connection.close }

    # Connections beanstalkd has accepted so far
    def total_connections
      @stats_connection.stats.total_connections
    end

    def enqueue_in_new_thread(count = 1)
      Thread.new { Array.new(count) { |i| Backburner::Worker.enqueue(TestJob, [i, 0]) } }.value
    end

    it "should reuse one connection for a thread's enqueues" do
      before_count = total_connections
      responses = enqueue_in_new_thread(5)
      assert_equal ["INSERTED"] * 5, responses.map { |res| res[:status] }
      assert_equal 1, total_connections - before_count
    end

    it "should give each thread its own connection" do
      before_count = total_connections
      2.times { enqueue_in_new_thread(2) }
      assert_equal 2, total_connections - before_count
    end

    it "should give a forked child its own connection" do
      skip "needs fork" unless Process.respond_to?(:fork)
      Thread.new do
        Backburner::Worker.enqueue(TestJob, [1, 0])
        before_child = total_connections
        pid = Process.fork do
          res = Backburner::Worker.enqueue(TestJob, [2, 0]) rescue nil
          exit!(res && res[:status] == "INSERTED" ? 0 : 1)
        end
        Process.wait(pid)
        assert_equal 0, $?.exitstatus, "the child's enqueue failed"
        assert_equal 1, total_connections - before_child, "the child should open its own connection"
        assert_equal "INSERTED", Backburner::Worker.enqueue(TestJob, [3, 0])[:status]
        assert_equal 1, total_connections - before_child, "the parent should keep its connection"
      end.join
    end

    it "should not reuse a connection that an error interrupted" do
      serializer = Backburner.configuration.job_serializer_proc
      Thread.new do
        Backburner::Worker.enqueue(TestJob, [1, 0])
        socket = Thread.current[:backburner_enqueue_connection].last.connection.connection
        # an interrupted command: its reply is left unread on the socket
        Backburner.configuration.job_serializer_proc = lambda { |body| socket.write("list-tube-used\r\n"); raise Timeout::Error }
        assert_raises(Timeout::Error) { Backburner::Worker.enqueue(TestJob, [2, 0]) }
        Backburner.configuration.job_serializer_proc = serializer
        assert_equal "INSERTED", Backburner::Worker.enqueue(TestJob, [3, 0])[:status]
      end.join
    ensure
      Backburner.configuration.job_serializer_proc = serializer
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
