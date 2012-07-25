require File.expand_path('../test_helper', __FILE__)

$worker_test_count = 0

class TestJob
  include Echelon::Job
  def self.perform(x, y); $worker_test_count += x + y; end
end

class TestAsyncJob
  include Echelon::Performable
  def self.foo(x, y); $worker_test_count = x * y; end
end

describe "Echelon::Worker module" do
  before { Echelon.default_queues.clear }

  describe "for enqueue class method" do
    it "should support enqueuing job" do
      Echelon::Worker.enqueue TestJob, [3, 4], :ttr => 100
      job, body = pop_one_job("test-job")
      assert_equal "TestJob", body["class"]
      assert_equal [3, 4], body["args"]
      assert_equal 100, job.ttr
      assert_equal Echelon.configuration.default_priority, job.pri
    end # simple

    it "should support enqueuing job with custom queue" do
      Echelon::Worker.enqueue TestJob, [6, 7], :queue => "test.bar", :pri => 5000
      job, body = pop_one_job("test.bar")
      assert_equal "TestJob", body["class"]
      assert_equal [6, 7], body["args"]
      assert_equal 0, job.delay
      assert_equal 5000, job.pri
      assert_equal Echelon.configuration.respond_timeout, job.ttr
    end # custom

    it "should support async job" do
      TestAsyncJob.async(:ttr => 100, :queue => "bar.baz.foo").foo(10, 5)
      job, body = pop_one_job("bar.baz.foo")
      assert_equal "TestAsyncJob", body["class"]
      assert_equal [nil, "foo", 10, 5], body["args"]
      assert_equal 100, job.ttr
      assert_equal Echelon.configuration.default_priority, job.pri
    end # async
  end # enqueue

  describe "for start class method" do
    it "should initialize and start the worker instance" do
      ech = stub
      Echelon::Worker.expects(:new).with("foo").returns(ech)
      ech.expects(:start)
      Echelon::Worker.start("foo")
    end
  end # start

  describe "for connection class method" do
    it "should return the beanstalk connection" do
      assert_equal "beanstalk://localhost", Echelon::Worker.connection.url
      assert_kind_of Beanstalk::Pool, Echelon::Worker.connection.beanstalk
    end
  end # connection

  describe "for tube_names accessor" do
    it "supports retrieving tubes" do
      worker = Echelon::Worker.new(["foo", "bar"])
      assert_equal ["foo", "bar"], worker.tube_names
    end
  end # tube_names

  describe "for prepare method" do
    it "should watch specified tubes" do
      worker = Echelon::Worker.new(["foo", "bar"])
      out = capture_stdout { worker.prepare }
      assert_equal ["demo.test.foo", "demo.test.bar"], worker.tube_names
      assert_same_elements ["demo.test.foo", "demo.test.bar"], Echelon::Worker.connection.list_tubes_watched.values.first
      assert_match /demo\.test\.foo/, out
    end # multiple

    it "should watch single tube" do
      worker = Echelon::Worker.new("foo")
      out = capture_stdout { worker.prepare }
      assert_equal ["demo.test.foo"], worker.tube_names
      assert_same_elements ["demo.test.foo"], Echelon::Worker.connection.list_tubes_watched.values.first
      assert_match /demo\.test\.foo/, out
    end # single

    it "should respect default_queues settings" do
      Echelon.default_queues.concat(["foo", "bar"])
      worker = Echelon::Worker.new
      out = capture_stdout { worker.prepare }
      assert_equal ["demo.test.foo", "demo.test.bar"], worker.tube_names
      assert_same_elements ["demo.test.foo", "demo.test.bar"], Echelon::Worker.connection.list_tubes_watched.values.first
      assert_match /demo\.test\.foo/, out
    end

    it "should support all tubes" do
      Echelon::Worker.any_instance.expects(:all_existing_queues).once.returns("bar")
      worker = Echelon::Worker.new
      out = capture_stdout { worker.prepare }
      assert_equal ["demo.test.bar"], worker.tube_names
      assert_same_elements ["demo.test.bar"], Echelon::Worker.connection.list_tubes_watched.values.first
      assert_match /demo\.test\.bar/, out
    end # all
  end # prepare

  describe "for work_one_job method" do
    it "should work an enqueued job" do
      $worker_test_count = 0
      Echelon::Worker.enqueue TestJob, [1, 2], :queue => "foo.bar"
      silenced(2) do
        worker = Echelon::Worker.new('foo.bar')
        worker.prepare
        worker.work_one_job
      end
      assert_equal 3, $worker_test_count
    end

    it "should work for an async job" do
      $worker_test_count = 0
      TestAsyncJob.async(:queue => "bar.baz").foo(3, 5)
      silenced(2) do
        worker = Echelon::Worker.new('bar.baz')
        worker.prepare
        worker.work_one_job
      end
      assert_equal 15, $worker_test_count
    end
  end # work_one_job
end # Echelon::Worker