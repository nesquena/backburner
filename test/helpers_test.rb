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
      assert_match(/Exception RuntimeError/, output)
    end
  end # exception_message

  describe "for queue_config" do
    before { Backburner.expects(:configuration).returns(stub(:tube_namespace => "test.foo.job", :namespace_separator => '.')) }

    it "accesses correct value for namespace" do
      assert_equal "test.foo.job", queue_config.tube_namespace
    end
  end # config

  describe "for expand_tube_name method" do
    before { Backburner.stubs(:configuration).returns(stub(:tube_namespace => "test.foo.job.", :namespace_separator => '.', :primary_queue => "backburner-jobs"))  }

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

    it "supports lambda in queue object" do
      test = stub(:queue => lambda { |job_class| "email/send_news" })
      assert_equal "test.foo.job.email/send-news", expand_tube_name(test)
    end # lambdas in queue object

    it "supports lambdas" do
      test = lambda { "email/send_news" }
      assert_equal "test.foo.job.email/send-news", expand_tube_name(test)
    end #lambdas
  end # expand_tube_name

  describe "for alternative namespace separator" do
    before { Backburner.stubs(:configuration).returns(stub(:tube_namespace => "test", :namespace_separator => '-', :primary_queue => "backburner-jobs"))  }

    it "uses alternative namespace separator" do
      assert_equal "test-queue-name", expand_tube_name("queue_name")
    end # simple string
  end

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

  describe "for resolve_max_job_retries method" do
    before do
      @original_max_job_retries = Backburner.configuration.max_job_retries
      Backburner.configure { |config| config.max_job_retries = 300 }
    end
    after { Backburner.configure { |config| config.max_job_retries = @original_max_job_retries } }

    it "supports fix num max_job_retries" do
      assert_equal 500, resolve_max_job_retries(500)
    end

    it "supports classes which respond to queue_max_job_retries" do
      job = stub(:queue_max_job_retries => 600)
      assert_equal 600, resolve_max_job_retries(job)
    end

    it "supports classes which return null queue_max_job_retries" do
      job = stub(:queue_max_job_retries => nil)
      assert_equal 300, resolve_max_job_retries(job)
    end

    it "supports classes which don't respond to queue_max_job_retries" do
      job = stub(:fake => true)
      assert_equal 300, resolve_max_job_retries(job)
    end

    it "supports default max_job_retries for null values" do
      assert_equal 300, resolve_max_job_retries(nil)
    end
  end # resolve_max_job_retries

  describe "for resolve_retry_delay method" do
    before do
      @original_retry_delay = Backburner.configuration.retry_delay
      Backburner.configure { |config| config.retry_delay = 300 }
    end
    after { Backburner.configure { |config| config.retry_delay = @original_retry_delay } }

    it "supports fix num retry_delay" do
      assert_equal 500, resolve_retry_delay(500)
    end

    it "supports classes which respond to queue_retry_delay" do
      job = stub(:queue_retry_delay => 600)
      assert_equal 600, resolve_retry_delay(job)
    end

    it "supports classes which return null queue_retry_delay" do
      job = stub(:queue_retry_delay => nil)
      assert_equal 300, resolve_retry_delay(job)
    end

    it "supports classes which don't respond to queue_retry_delay" do
      job = stub(:fake => true)
      assert_equal 300, resolve_retry_delay(job)
    end

    it "supports default retry_delay for null values" do
      assert_equal 300, resolve_retry_delay(nil)
    end
  end # resolve_retry_delay

  describe "for resolve_retry_delay_proc method" do
    before do
      @config_retry_delay_proc = lambda { |x, y| x + y } # Default config proc adds two values
      @override_delay_proc = lambda { |x, y| x - y } # Overriden proc subtracts values
      @original_retry_delay_proc = Backburner.configuration.retry_delay_proc
      Backburner.configure { |config| config.retry_delay_proc = @config_retry_delay_proc }
    end
    after { Backburner.configure { |config| config.retry_delay_proc = @original_retry_delay_proc } }

    # Rather than compare Procs execute them and compare the output
    it "supports proc retry_delay_proc" do
      assert_equal @override_delay_proc.call(2, 1), resolve_retry_delay_proc(@override_delay_proc).call(2, 1)
    end

    it "supports classes which respond to queue_retry_delay_proc" do
      job = stub(:queue_retry_delay_proc => @override_delay_proc)
      assert_equal @override_delay_proc.call(2, 1), resolve_retry_delay_proc(job).call(2, 1)
    end

    it "supports classes which return null queue_retry_delay_proc" do
      job = stub(:queue_retry_delay_proc => nil)
      assert_equal @original_retry_delay_proc.call(2, 1), resolve_retry_delay_proc(job).call(2, 1)
    end

    it "supports classes which don't respond to queue_retry_delay_proc" do
      job = stub(:fake => true)
      assert_equal @original_retry_delay_proc.call(2, 1), resolve_retry_delay_proc(job).call(2, 1)
    end

    it "supports default retry_delay_proc for null values" do
      assert_equal @original_retry_delay_proc.call(2, 1), resolve_retry_delay_proc(nil).call(2, 1)
    end
  end # resolve_retry_delay_proc
end
