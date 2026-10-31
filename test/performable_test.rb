require File.expand_path('../test_helper', __FILE__)

class TestObj
  ID = 56
  def id; ID; end
  def self.find(id); TestObj.new if id == ID; end
  def foo(state, state2); "bar #{state} #{state2}"; end
  def self.bar(state, state2); "baz #{state} #{state2}"; end
end

class PerformableTestObj < TestObj
  include Backburner::Performable
end

class AutomagicTestObj < TestObj
  # Don't include Backburner::Performable because it should be automagically included
  def qux(state, state2); "garply #{state} #{state2}" end
  def self.garply(state, state2); "thud #{state} #{state2}" end
  def qux?; "garply!" end
end

class AsyncInstanceMethodsTestObj < PerformableTestObj; end
class AsyncStaticMethodsTestObj < PerformableTestObj; end

class AsyncSettingsTestObj < TestObj
  include Backburner::Performable
  queue "performable-settings"
  queue_priority 10
  queue_respond_timeout 300
  queue_max_job_retries 3
  handle_asynchronously :foo
  handle_static_asynchronously :bar
end

class QueueThenPerformableTestObj < TestObj
  include Backburner::Queue
  queue "queue-then-performable"
  queue_priority 20
  queue_respond_timeout 200
  include Backburner::Performable
end



describe "Backburner::Performable module" do
  after { ENV["TEST"] = nil }

  describe "for async instance method" do
    it "should invoke worker enqueue" do
      Backburner::Worker.expects(:enqueue).with(PerformableTestObj, [56, :foo, true, false], has_entries(:pri => 5000, :queue => "foo"))
      PerformableTestObj.new.async(:pri => 5000, :queue => "foo").foo(true, false)
    end
  end # async instance

  describe "for async class method" do
    it "should invoke worker enqueue" do
      Backburner::Worker.expects(:enqueue).with(PerformableTestObj, [nil, :bar, true, false], has_entries(:pri => 5000, :queue => "foo"))
      PerformableTestObj.async(:pri => 5000, :queue => "foo").bar(true, false)
    end
  end # async class

  describe "for perform class method" do
    it "should work for instance" do
      assert_equal "bar true false", PerformableTestObj.perform(PerformableTestObj::ID, :foo, true, false)
    end # instance

    it "should work for class level" do
      assert_equal "baz false true", PerformableTestObj.perform(nil, :bar, false, true)
    end # class
  end # perform

  describe "for handle_asynchronously class method" do
    it "should automagically asynchronously proxy calls to the method" do
      Backburner::Performable.handle_asynchronously(AutomagicTestObj, :qux, :pri => 5000, :queue => "qux")

      Backburner::Worker.expects(:enqueue).with(AutomagicTestObj, [56, :qux_without_async, true, false], has_entries(:pri => 5000, :queue => "qux"))
      AutomagicTestObj.new.qux(true, false)
    end

    it "should work for class methods, too" do
      Backburner::Performable.handle_static_asynchronously(AutomagicTestObj, :garply, :pri => 5000, :queue => "garply")

      Backburner::Worker.expects(:enqueue).with(AutomagicTestObj, [nil, :garply_without_async, true, false], has_entries(:pri => 5000, :queue => "garply"))
      AutomagicTestObj.garply(true, false)
    end

    it "should correctly handle punctuation" do
      Backburner::Performable.handle_asynchronously(AutomagicTestObj, :qux?)

      Backburner::Worker.expects(:enqueue).with(AutomagicTestObj, [56, :qux_without_async?], {})
      AutomagicTestObj.new.qux?
    end

    it "should be available for instance methods on any class that includes the Performable module" do
      AsyncInstanceMethodsTestObj.handle_asynchronously :foo, pri: 5000, queue: 'qux'
      Backburner::Worker.expects(:enqueue).with(AsyncInstanceMethodsTestObj, [56, :foo_without_async, true, false], has_entries(:pri => 5000, :queue => "qux"))
      AsyncInstanceMethodsTestObj.new.foo(true, false)
    end

    it "should be available for class methods on any class that includes the Performable module" do
      AsyncStaticMethodsTestObj.handle_static_asynchronously :bar, pri: 5000, queue: 'garply'
      Backburner::Worker.expects(:enqueue).with(AsyncStaticMethodsTestObj, [nil, :bar_without_async, true, false], has_entries(:pri => 5000, :queue => "garply"))
      AsyncStaticMethodsTestObj.bar(true, false)
    end

    describe "on a class with queue settings" do
      before { clear_jobs!("performable-settings") }
      after { clear_jobs!("performable-settings") }

      it "keeps the class's queue settings" do
        assert_equal "performable-settings", AsyncSettingsTestObj.queue
        assert_equal 10, AsyncSettingsTestObj.queue_priority
        assert_equal 300, AsyncSettingsTestObj.queue_respond_timeout
        assert_equal 3, AsyncSettingsTestObj.queue_max_job_retries
      end

      it "enqueues instance and class method calls with the class's queue settings" do
        AsyncSettingsTestObj.new.foo(true, false)
        AsyncSettingsTestObj.bar(false, true)
        [[56, "foo_without_async", true, false], [nil, "bar_without_async", false, true]].each do |args|
          pop_one_job("performable-settings") do |job, body|
            assert_equal ["AsyncSettingsTestObj", args], [body["class"], body["args"]]
            assert_equal [10, 300], [job.pri, job.ttr]
            job.delete
          end
        end
      end
    end
  end # handle_asynchronously

  describe "when included after Backburner::Queue" do
    it "keeps the queue settings the class already set" do
      assert_equal "queue-then-performable", QueueThenPerformableTestObj.queue
      assert_equal 20, QueueThenPerformableTestObj.queue_priority
      assert_equal 200, QueueThenPerformableTestObj.queue_respond_timeout
    end
  end
end
