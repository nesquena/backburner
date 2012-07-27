require File.expand_path('../test_helper', __FILE__)

$worker_test_count = 0

class TestJob
  include Backburner::Queue
  def self.perform(x, y); $worker_test_count += x + y; end
end

class TestFailJob
  include Backburner::Queue
  def self.perform(x, y); raise RuntimeError; end
end

class TestAsyncJob
  include Backburner::Performable
  def self.foo(x, y); $worker_test_count = x * y; end
end

describe "Backburner::Worker module" do
  before { Backburner.default_queues.clear }

  describe "for enqueue class method" do
    it "should support enqueuing job" do
      Backburner::Worker.enqueue TestJob, [3, 4], :ttr => 100
      job, body = pop_one_job("test-job")
      assert_equal "TestJob", body["class"]
      assert_equal [3, 4], body["args"]
      assert_equal 100, job.ttr
      assert_equal Backburner.configuration.default_priority, job.pri
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
      assert_kind_of Beanstalk::Pool, Backburner::Worker.connection.beanstalk
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
      assert_same_elements ["demo.test.foo", "demo.test.bar"], Backburner::Worker.connection.list_tubes_watched.values.first
      assert_match /demo\.test\.foo/, out
    end # multiple

    it "should watch single tube" do
      worker = Backburner::Worker.new("foo")
      out = capture_stdout { worker.prepare }
      assert_equal ["demo.test.foo"], worker.tube_names
      assert_same_elements ["demo.test.foo"], Backburner::Worker.connection.list_tubes_watched.values.first
      assert_match /demo\.test\.foo/, out
    end # single

    it "should respect default_queues settings" do
      Backburner.default_queues.concat(["foo", "bar"])
      worker = Backburner::Worker.new
      out = capture_stdout { worker.prepare }
      assert_equal ["demo.test.foo", "demo.test.bar"], worker.tube_names
      assert_same_elements ["demo.test.foo", "demo.test.bar"], Backburner::Worker.connection.list_tubes_watched.values.first
      assert_match /demo\.test\.foo/, out
    end

    it "should assign based on all tubes" do
      Backburner::Worker.any_instance.expects(:all_existing_queues).once.returns("bar")
      worker = Backburner::Worker.new
      out = capture_stdout { worker.prepare }
      assert_equal ["demo.test.bar"], worker.tube_names
      assert_same_elements ["demo.test.bar"], Backburner::Worker.connection.list_tubes_watched.values.first
      assert_match /demo\.test\.bar/, out
    end # all assign

    it "should properly retrieve all tubes" do
      worker = Backburner::Worker.new
      out = capture_stdout { worker.prepare }
      assert_contains worker.tube_names, "demo.test.test-job"
      assert_contains Backburner::Worker.connection.list_tubes_watched.values.first, "demo.test.test-job"
      assert_match /demo\.test\.test-job/, out
    end # all read
  end # prepare

  describe "for work_one_job method" do
    it "should work an enqueued job" do
      $worker_test_count = 0
      Backburner::Worker.enqueue TestJob, [1, 2], :queue => "foo.bar"
      silenced(2) do
        worker = Backburner::Worker.new('foo.bar')
        worker.prepare
        worker.work_one_job
      end
      assert_equal 3, $worker_test_count
    end # enqueue

    it "should work an enqueued failing job" do
      $worker_test_count = 0
      Backburner::Worker.enqueue TestFailJob, [1, 2], :queue => "foo.bar.fail"
      out = silenced(2) do
        worker = Backburner::Worker.new('foo.bar.fail')
        worker.prepare
        worker.work_one_job
      end
      assert_match(/Exception RuntimeError/, out)
      assert_equal 0, $worker_test_count
    end # fail

    it "should work for an async job" do
      $worker_test_count = 0
      TestAsyncJob.async(:queue => "bar.baz").foo(3, 5)
      silenced(2) do
        worker = Backburner::Worker.new('bar.baz')
        worker.prepare
        worker.work_one_job
      end
      assert_equal 15, $worker_test_count
    end # async
  end # work_one_job
end # Backburner::Worker