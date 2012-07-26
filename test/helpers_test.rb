require File.expand_path('../test_helper', __FILE__)

describe "Backburner::Helpers module" do
  include Backburner::Helpers

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
      assert_equal Backburner, constantize("Backburner")
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

  describe "for tube_namespace" do
    before { Backburner.expects(:configuration).returns(stub(:tube_namespace => "test.foo.job")) }

    it "accesses correct value" do
      assert_equal "test.foo.job", tube_namespace
    end
  end # tube_namespace

  describe "for expand_tube_name method" do
    before { Backburner.expects(:configuration).returns(stub(:tube_namespace => "test.foo.job.")) }

    it "supports base strings" do
      assert_equal "test.foo.job.email/send-news", expand_tube_name("email/send_news")
    end # simple string

    it "supports qualified strings" do
      assert_equal "test.foo.job.email/send-news", expand_tube_name("test.foo.job.email/send_news")
    end # qualified string

    it "supports base symbols" do
      assert_equal "test.foo.job.email/send-news", expand_tube_name(:"email/send_news")
    end # symbols

    it "supports queue names" do
      test = stub(:queue => "email/send_news")
      assert_equal "test.foo.job.email/send-news", expand_tube_name(test)
    end # queue names

    it "supports class names" do
      assert_equal "test.foo.job.runtime-error", expand_tube_name(RuntimeError)
    end # class names
  end # expand_tube_name
end