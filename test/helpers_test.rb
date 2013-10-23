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

  describe "for queue_config" do
    before { Backburner.expects(:configuration).returns(stub(:tube_namespace => "test.foo.job")) }

    it "accesses correct value for namespace" do
      assert_equal "test.foo.job", queue_config.tube_namespace
    end
  end # config

  describe "for expand_tube_name method" do
    before { Backburner.stubs(:configuration).returns(stub(:tube_namespace => "test.foo.job.", :primary_queue => "backburner-jobs"))  }

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
      assert_equal "test.foo.job.backburner-jobs", expand_tube_name(RuntimeError)
    end # class names
  end # expand_tube_name

  describe "for resolve_priority method" do
    before do
      @original_queue_priority = Backburner.configuration.default_priority
      Backburner.configure { |config| config.default_priority = 1000 }
    end
    after do
      Backburner.configure { |config| config.default_priority = @original_queue_priority }
      Backburner.configure { |config| config.priority_labels = Backburner::Configuration::PRIORITY_LABELS }
    end

    it "supports fix num priority" do
      assert_equal 500, resolve_priority(500)
    end

    it "supports baked in priority alias" do
      assert_equal 200, resolve_priority(:low)
      assert_equal 0,   resolve_priority(:high)
    end

    it "supports custom priority alias" do
      Backburner.configure { |config| config.priority_labels = { :foo => 5 } }
      assert_equal 5,   resolve_priority(:foo)
    end

    it "supports aliased priority alias" do
      Backburner.configure { |config| config.priority_labels = { :foo => 5, :bar => 'foo' } }
      assert_equal 5,   resolve_priority(:bar)
    end

    it "supports classes which respond to queue_priority" do
      job = stub(:queue_priority => 600)
      assert_equal 600, resolve_priority(job)
    end

    it "supports classes which respond to queue_priority with named alias" do
      job = stub(:queue_priority => :low)
      assert_equal 200, resolve_priority(job)
    end

    it "supports classes which returns null queue_priority" do
      job = stub(:queue_priority => nil)
      assert_equal 1000, resolve_priority(job)
    end

    it "supports classes which don't respond to queue_priority" do
      job = stub(:fake => true)
      assert_equal 1000, resolve_priority(job)
    end

    it "supports default pri for null values" do
      assert_equal 1000, resolve_priority(nil)
    end
  end # resolve_priority

  describe "for resolve_respond_timeout method" do
    before do
      @original_respond_timeout = Backburner.configuration.respond_timeout
      Backburner.configure { |config| config.respond_timeout = 300 }
    end
    after { Backburner.configure { |config| config.respond_timeout = @original_respond_timeout } }

    it "supports fix num respond_timeout" do
      assert_equal 500, resolve_respond_timeout(500)
    end

    it "supports classes which respond to queue_respond_timeout" do
      job = stub(:queue_respond_timeout => 600)
      assert_equal 600, resolve_respond_timeout(job)
    end

    it "supports classes which returns null queue_respond_timeout" do
      job = stub(:queue_respond_timeout => nil)
      assert_equal 300, resolve_respond_timeout(job)
    end

    it "supports classes which don't respond to queue_respond_timeout" do
      job = stub(:fake => true)
      assert_equal 300, resolve_respond_timeout(job)
    end

    it "supports default ttr for null values" do
      assert_equal 300, resolve_respond_timeout(nil)
    end
  end # resolve_respond_timeout
end