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
  end
end
