require File.expand_path('../test_helper', __FILE__)
require File.expand_path('../fixtures/test_jobs', __FILE__)
require File.expand_path('../fixtures/hooked', __FILE__)

describe "Backburner::Worker module" do
  before do
    Backburner.default_queues.clear
    clear_jobs!(Backburner.configuration.primary_queue, "test-plain", "test.bar", "bar.baz.foo")
  end

  describe "for enqueue class method" do
    it "should support enqueuing plain job" do
      Backburner::Worker.enqueue TestPlainJob, [7, 9], :ttr => 100, :pri => 2000
      job, body = pop_one_job("test-plain")
      assert_equal "TestPlainJob", body["class"]
      assert_equal [7, 9], body["args"]
      assert_equal 100, job.ttr
      assert_equal 2000, job.pri
    end # plain

    it "should support enqueuing job with class queue priority" do
      Backburner::Worker.enqueue TestJob, [3, 4], :ttr => 100
      job, body = pop_one_job
      assert_equal "TestJob", body["class"]
      assert_equal [3, 4], body["args"]
      assert_equal 100, job.ttr
      assert_equal 100, job.pri
    end # queue priority

    it "should support enqueuing job with specified named priority" do
      Backburner::Worker.enqueue TestJob, [3, 4], :ttr => 100, :pri => 'high'
      job, body = pop_one_job
      assert_equal "TestJob", body["class"]
      assert_equal [3, 4], body["args"]
      assert_equal 100, job.ttr
      assert_equal 0, job.pri
    end # queue named priority

    it "should support enqueuing job with class queue respond_timeout" do
      Backburner::Worker.enqueue TestJob, [3, 4]
      job, body = pop_one_job
      assert_equal "TestJob", body["class"]
      assert_equal [3, 4], body["args"]
      assert_equal 300, job.ttr
      assert_equal 100, job.pri
    end # queue respond_timeout

    it "should support enqueuing job with custom queue" do
      Backburner::Worker.enqueue TestJob, [6, 7], :queue => "test.bar", :pri => 5000
      job, body = pop_one_job("test.bar")
      assert_equal "TestJob", body["class"]
      assert_equal [6, 7], body["args"]
      assert_equal 0, job.delay
      assert_equal 5000, job.pri
      assert_equal 300, job.ttr
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
end # Backburner::Worker