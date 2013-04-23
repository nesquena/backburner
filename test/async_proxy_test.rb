require File.expand_path('../test_helper', __FILE__)

class AsyncUser; end

describe "Backburner::AsyncProxy class" do
  before do
    Backburner.default_queues.clear
    clear_jobs!(Backburner.configuration.primary_queue)
  end

  describe "for method_missing enqueue" do
    should "enqueue job onto worker with no args" do
      @async = Backburner::AsyncProxy.new(AsyncUser, 10, :pri => 1000, :ttr => 100)
      @async.foo
      job, body = pop_one_job
      assert_equal "AsyncUser", body["class"]
      assert_equal [10, "foo"], body["args"]
      assert_equal 100, job.ttr
      assert_equal 1000, job.pri
      job.delete
    end

    should "enqueue job onto worker with args" do
      @async = Backburner::AsyncProxy.new(AsyncUser, 10, :pri => 1000, :ttr => 100)
      @async.bar(1, 2, 3)
      job, body = pop_one_job
      assert_equal "AsyncUser", body["class"]
      assert_equal [10, "bar", 1, 2, 3], body["args"]
      assert_equal 100, job.ttr
      assert_equal 1000, job.pri
      job.delete
    end
  end # method_missing
end # AsyncProxy