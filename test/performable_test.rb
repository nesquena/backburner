require File.expand_path('../test_helper', __FILE__)
require 'delegate'

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

module JobMethodsTestMixin
  def mixed_in; "mixed in"; end
end

class JobMethodsTestObj < TestObj
  include Backburner::Performable
  include JobMethodsTestMixin
  def self.find(id); new if id == ID; end
  def to_s; "own to_s"; end
  def self.to_s; "own class to_s"; end
  def method_missing(name, *args); name == :dynamic ? "dynamic" : super; end
  def respond_to_missing?(name, include_private = false); name == :dynamic || super; end
  private
  def hidden; "hidden"; end
  def self.class_hidden; "class hidden"; end
  private_class_method :class_hidden
end

class PrivateAsyncTestObj < TestObj
  include Backburner::Performable
  def self.find(id); new if id == ID; end
  private
  def secret(a); "secret #{a}"; end
  def self.class_secret(a); "class secret #{a}"; end
  private_class_method :class_secret
  handle_asynchronously :secret
  handle_static_asynchronously :class_secret
end

class AnonymousSourcesTestObj < Struct.new(:id)
  include Backburner::Performable
  prepend(Module.new { def print; "traced #{super}"; end })
  def self.find(id); new(id) if id == TestObj::ID; end
  def print; "printed"; end
end

class AnonymousSourcesTestStruct < Struct.new(:id) do
    def display; "displayed"; end
  end
  include Backburner::Performable
  def self.find(id); new(id); end
end

class DelegatorJobTestObj < SimpleDelegator
  include Backburner::Performable
  def self.find(id); new(TestObj.new) if id == TestObj::ID; end
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

    it "calls a method named by a string, as a job body has it" do
      assert_equal "bar 1 2", PerformableTestObj.perform(PerformableTestObj::ID, "foo", 1, 2)
      assert_equal "baz 1 2", PerformableTestObj.perform(nil, "bar", 1, 2)
    end

    it "calls methods the class overrides, gets from a module it includes, or handles in method_missing" do
      id = JobMethodsTestObj::ID
      assert_equal "own to_s", JobMethodsTestObj.perform(id, :to_s)
      assert_equal "own class to_s", JobMethodsTestObj.perform(nil, :to_s)
      assert_equal "mixed in", JobMethodsTestObj.perform(id, :mixed_in)
      assert_equal "dynamic", JobMethodsTestObj.perform(id, :dynamic)
    end

    it "only calls methods the job class defines, not ones every object or class has" do
      id = JobMethodsTestObj::ID
      [[id, :frozen?], [id, "instance_variables"], [nil, :instance_variable_set, :@probe, 1], [nil, "name"]].each do |args|
        error = assert_raises(NoMethodError) { JobMethodsTestObj.perform(*args) }
        assert_equal args[1].to_sym, error.name
      end
      refute JobMethodsTestObj.instance_variable_defined?(:@probe)
    end

    it "calls the class's private methods, as handle_asynchronously does for a private method" do
      assert_equal "hidden", JobMethodsTestObj.perform(JobMethodsTestObj::ID, :hidden)
      assert_equal "class hidden", JobMethodsTestObj.perform(nil, :class_hidden)
      assert_equal "secret 1", PrivateAsyncTestObj.perform(PrivateAsyncTestObj::ID, :secret_without_async, 1)
      assert_equal "class secret 2", PrivateAsyncTestObj.perform(nil, :class_secret_without_async, 2)
    end

    it "doesn't call a method Object's singleton class gets from a library" do
      require 'psych'
      assert_raises(NoMethodError) { JobMethodsTestObj.perform(nil, :yaml_tag, "!backburner-test") }
      refute Psych.load_tags.key?("!backburner-test")
    end

    it "doesn't call method_missing itself, or core methods it would handle" do
      id = JobMethodsTestObj::ID
      assert_raises(NoMethodError) { JobMethodsTestObj.perform(id, :method_missing, :dynamic) }
      assert_raises(NoMethodError) { JobMethodsTestObj.perform(id, :system, "true") }
    end

    it "calls the app's methods named like a core method from an anonymous module or superclass" do
      assert_equal "traced printed", AnonymousSourcesTestObj.perform(TestObj::ID, :print)
      assert_equal "displayed", AnonymousSourcesTestStruct.perform(1, :display)
    end

    it "calls a Delegator's delegated methods, but not its copy of Kernel's" do
      id = TestObj::ID
      assert_equal "bar 1 2", DelegatorJobTestObj.perform(id, :foo, 1, 2)
      [[:send, :instance_variable_set, :@probe, 1], [:instance_variable_set, :@probe, 1], [:system, "true"], [:public_send, :foo, 1, 2]].each do |args|
        error = assert_raises(NoMethodError) { DelegatorJobTestObj.perform(id, *args) }
        assert_equal args[0], error.name
      end
      refute DelegatorJobTestObj.find(id).instance_variable_defined?(:@probe)
    end

    it "doesn't call Backburner's own class methods" do
      assert_raises(NoMethodError) { JobMethodsTestObj.perform(nil, :queue_priority, 99) }
      assert_nil JobMethodsTestObj.queue_priority
      assert_raises(NoMethodError) { JobMethodsTestObj.perform(nil, :perform, nil, :bar, 1, 2) }
    end

    it "still raises NoMethodError for a method nothing defines" do
      assert_raises(NoMethodError) { JobMethodsTestObj.perform(JobMethodsTestObj::ID, :nonexistent) }
      assert_raises(NoMethodError) { JobMethodsTestObj.perform(nil, :nonexistent) }
    end
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
