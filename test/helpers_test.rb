require File.expand_path('../test_helper', __FILE__)

describe "Echelon::Helpers module" do
  include Echelon::Helpers

  describe "for classify method" do
    it "should support simple classify" do
      assert_equal "FooBarBaz", classify("foo-bar-baz")
    end

    it "should not affect existing classified strings" do
      assert_equal "Foo::BarBaz", classify("Foo::BarBaz")
    end
  end # classify

  describe "for constantize method" do
    it "should constantize known constant" do
      assert_equal Echelon, constantize("Echelon")
    end

    it "should properly report when constant is undefined" do
      assert_raises(NameError) { constantize("FakeObject") }
    end
  end # constantize

  describe "for dasherize method" do
    it "should not harm existing dashed names" do
      assert_equal "foo/bar-baz", dasherize("foo/bar-baz")
    end

    it "should properly convert simple names to dashes" do
      assert_equal "foo-bar", dasherize("FooBar")
    end

    it "should properly convert class to dash with namespace" do
      assert_equal "foo/bar-baz", dasherize("Foo::BarBaz")
    end
  end # dasherize

  describe "for exception_message method" do
    it "prints out message about failure" do
      output = exception_message(RuntimeError.new("test"))
      assert_match /Exception RuntimeError/, output
    end
  end # exception_message
end