require File.expand_path('../test_helper', __FILE__)

class TestObj
  include Backburner::Performable
  ID = 56
  def id; ID; end
  def self.find(id); TestObj.new if id == ID; end
  def foo(state, state2); "bar #{state} #{state2}"; end
  def self.bar(state, state2); "baz #{state} #{state2}"; end
end

describe "Backburner::Performable module" do
  after { ENV["TEST"] = nil }

  describe "for async instance method" do
    it "should invoke worker enqueue" do
      Backburner::Worker.expects(:enqueue).with(TestObj, [56, :foo, true, false], has_entries(:pri => 5000, :queue => "foo"))
      TestObj.new.async(:pri => 5000, :queue => "foo").foo(true, false)
    end
  end # async instance

  describe "for async class method" do
    it "should invoke worker enqueue" do
      Backburner::Worker.expects(:enqueue).with(TestObj, [nil, :bar, true, false], has_entries(:pri => 5000, :queue => "foo"))
      TestObj.async(:pri => 5000, :queue => "foo").bar(true, false)
    end
  end # async class

  describe "for perform class method" do
    it "should work for instance" do
      assert_equal "bar true false", TestObj.perform(TestObj::ID, :foo, true, false)
    end # instance

    it "should work for class level" do
      assert_equal "baz false true", TestObj.perform(nil, :bar, false, true)
    end # class
  end # perform
end