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

    it "shortens the backtrace paths under a working directory that has regexp characters in its name" do
      ["jobs[1]", "jobs["].each do |name|
        Dir.mktmpdir do |root|
          dir = File.join(File.realpath(root), name)
          Dir.mkdir(dir)
          error = RuntimeError.new("test")
          error.set_backtrace(["#{dir}/app/jobs/report.rb:3:in `perform'"])
          output = Dir.chdir(dir) { exception_message(error) }
          assert_equal "Exception RuntimeError -> test\n   app/jobs/report.rb:3:in `perform'", output, name
        end
      end
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

    it "removes prefix if configured as nil" do
      Backburner.stubs(:configuration).returns(stub(:tube_namespace => nil, :namespace_separator => '.'))

      test = stub(:queue => "email/send_news")
      assert_equal "email/send-news", expand_tube_name(test)
    end

    it "removes prefix if configured as false" do
      Backburner.stubs(:configuration).returns(stub(:tube_namespace => false, :namespace_separator => '.'))

      test = stub(:queue => "email/send_news")
      assert_equal "email/send-news", expand_tube_name(test)
    end

    # Tubes of 1.7.0 with an empty namespace hold queued jobs: keep their names
    it "starts names with the separator if configured as empty" do
      Backburner.stubs(:configuration).returns(stub(:tube_namespace => "", :namespace_separator => '.', :primary_queue => "backburner-jobs"))

      assert_equal ".email/send-news", expand_tube_name("email/send_news")
      assert_equal ".email/send-news", expand_tube_name(stub(:queue => "email/send_news"))
      assert_equal ".backburner-jobs", expand_tube_name(RuntimeError)
      assert_equal ".mailers", expand_tube_name("mailers")
    end

    # A tube name is where queued jobs wait, so a namespace that works keeps every name it gives, including
    # the odd ones of queue names that start with the namespace ("appmail" -> "app.mail")
    it "keeps the tube names it gives for namespaces without regexp characters other than dots" do
      queues = lambda do |namespace, separator|
        ["default", "mailers", "production_mailers", "newsletter_sender", "email/send_news", "Admin::ReportJob",
         "#{namespace}mail", "#{namespace}-reports", "#{namespace.tr('.', '-')}-sync", "#{namespace}#{separator}reports"]
      end
      {
        ["backburner.worker.queue", "."] => %w[
          backburner.worker.queue.default backburner.worker.queue.mailers backburner.worker.queue.production-mailers
          backburner.worker.queue.newsletter-sender backburner.worker.queue.email/send-news
          backburner.worker.queue.admin/report-job backburner.worker.queue.mail backburner.worker.queue.-reports
          backburner.worker.queue.-sync backburner.worker.queue.reports backburner.worker.queue.backburner-jobs
        ],
        ["backburner.worker.queue", "_"] => %w[
          backburner.worker.queue_default backburner.worker.queue_mailers backburner.worker.queue_production-mailers
          backburner.worker.queue_newsletter-sender backburner.worker.queue_email/send-news
          backburner.worker.queue_admin/report-job backburner.worker.queue_mail backburner.worker.queue_-reports
          backburner.worker.queue_-sync backburner.worker.queue_-reports backburner.worker.queue_backburner-jobs
        ],
        ["backburner", "."] => %w[
          backburner.default backburner.mailers backburner.production-mailers backburner.newsletter-sender
          backburner.email/send-news backburner.admin/report-job backburner.mail backburner.-reports backburner.-sync
          backburner.reports backburner.-jobs
        ],
        ["backburner", "_"] => %w[
          backburner_default backburner_mailers backburner_production-mailers backburner_newsletter-sender
          backburner_email/send-news backburner_admin/report-job backburner_mail backburner_-reports backburner_-sync
          backburner_-reports backburner_-jobs
        ],
        ["app", "."] => %w[
          app.default app.mailers app.production-mailers app.newsletter-sender app.email/send-news app.admin/report-job
          app.mail app.-reports app.-sync app.reports app.backburner-jobs
        ],
        ["app", "_"] => %w[
          app_default app_mailers app_production-mailers app_newsletter-sender app_email/send-news app_admin/report-job
          app_mail app_-reports app_-sync app_-reports app_backburner-jobs
        ],
        ["app.prod", "."] => %w[
          app.prod.default app.prod.mailers app.prod.production-mailers app.prod.newsletter-sender
          app.prod.email/send-news app.prod.admin/report-job app.prod.mail app.prod.-reports app.prod.-sync
          app.prod.reports app.prod.backburner-jobs
        ],
        ["app.prod", "_"] => %w[
          app.prod_default app.prod_mailers app.prod_production-mailers app.prod_newsletter-sender
          app.prod_email/send-news app.prod_admin/report-job app.prod_mail app.prod_-reports app.prod_-sync
          app.prod_-reports app.prod_backburner-jobs
        ],
        ["my-app", "."] => %w[
          my-app.default my-app.mailers my-app.production-mailers my-app.newsletter-sender my-app.email/send-news
          my-app.admin/report-job my-app.mail my-app.-reports my-app.-sync my-app.reports my-app.backburner-jobs
        ],
        ["my-app", "_"] => %w[
          my-app_default my-app_mailers my-app_production-mailers my-app_newsletter-sender my-app_email/send-news
          my-app_admin/report-job my-app_mail my-app_-reports my-app_-sync my-app_-reports my-app_backburner-jobs
        ],
        ["MyApp", "."] => %w[
          MyApp.default MyApp.mailers MyApp.production-mailers MyApp.newsletter-sender MyApp.email/send-news
          MyApp.admin/report-job MyApp.my-appmail MyApp.my-app-reports MyApp.my-app-sync MyApp.my-app.reports
          MyApp.backburner-jobs
        ],
        ["MyApp", "_"] => %w[
          MyApp_default MyApp_mailers MyApp_production-mailers MyApp_newsletter-sender MyApp_email/send-news
          MyApp_admin/report-job MyApp_my-appmail MyApp_my-app-reports MyApp_my-app-sync MyApp_my-app-reports
          MyApp_backburner-jobs
        ]
      }.each do |(namespace, separator), tube_names|
        Backburner.stubs(:configuration).returns(stub(:tube_namespace => namespace, :namespace_separator => separator, :primary_queue => "backburner-jobs"))
        assert_equal tube_names, queues.call(namespace, separator).map { |queue| expand_tube_name(queue) } + [expand_tube_name(RuntimeError)],
          [namespace, separator].inspect
      end
    end

    it "matches a namespace that isn't a valid regexp literally" do
      { "app(" => ["app(.default", "app(.mail"], "jobs\\" => ["jobs\\.default", "jobs\\.mail"] }.each do |namespace, tube_names|
        Backburner.stubs(:configuration).returns(stub(:tube_namespace => namespace, :namespace_separator => ".", :primary_queue => "backburner-jobs"))
        assert_equal tube_names, [expand_tube_name("default"), expand_tube_name("#{namespace}mail")], namespace
      end
    end

    it "uses the bare primary queue without a prefix" do
      [nil, false].each do |namespace|
        Backburner.stubs(:configuration).returns(stub(:tube_namespace => namespace, :namespace_separator => '-', :primary_queue => "backburner-jobs"))
        assert_equal "backburner-jobs", expand_tube_name(RuntimeError), namespace.inspect
        assert_equal "queue-name", expand_tube_name("queue_name"), namespace.inspect
      end
    end
  end # expand_tube_name

  describe "for alternative namespace separator" do
    before { Backburner.stubs(:configuration).returns(stub(:tube_namespace => "test", :namespace_separator => '-', :primary_queue => "backburner-jobs"))  }

    it "uses alternative namespace separator" do
      assert_equal "test-queue-name", expand_tube_name("queue_name")
    end # simple string

    it "joins the namespace and queue name without a separator if configured as empty" do
      Backburner.stubs(:configuration).returns(stub(:tube_namespace => "test", :namespace_separator => '', :primary_queue => "backburner-jobs"))
      assert_equal "testqueue-name", expand_tube_name("queue_name")
      assert_equal "testbackburner-jobs", expand_tube_name(RuntimeError)
    end

    it "keeps a trailing dot in the namespace when the separator is empty" do
      Backburner.stubs(:configuration).returns(stub(:tube_namespace => "test.", :namespace_separator => '', :primary_queue => "backburner-jobs"))
      assert_equal "test.queue-name", expand_tube_name("queue_name")
    end
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

    it "supports a priority label as the default" do
      Backburner.configure { |config| config.default_priority = :high }
      assert_equal 0, resolve_priority(nil)
      assert_equal 0, resolve_priority(stub(:queue_priority => nil))
      assert_equal 0, resolve_priority(:unknown_label)
      assert_equal 200, resolve_priority(:low)
    end

    it "supports a custom or aliased priority label as the default" do
      Backburner.configure { |config| config.priority_labels = { :foo => 5, :bar => 'foo' }; config.default_priority = 'bar' }
      assert_equal 5, resolve_priority(nil)
    end

    it "leaves an unknown default label as configured" do
      Backburner.configure { |config| config.default_priority = :unknown_label }
      assert_equal :unknown_label, resolve_priority(nil)
    end

    it "stops at a cycle of priority labels" do
      Backburner.configure { |config| config.priority_labels = { :a => :b, :b => 'a' }; config.default_priority = :a }
      assert_equal :a, resolve_priority(nil), "a default label cycle is left as configured"
      Backburner.configure { |config| config.default_priority = 1000 }
      assert_equal 1000, resolve_priority(:b), "a job label cycle falls back to the default"
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

    it "rounds a fractional respond_timeout up to whole seconds, from a value, a class or the default" do
      assert_equal 1, resolve_respond_timeout(0.2)
      assert_equal 2, resolve_respond_timeout(stub(:queue_respond_timeout => 1.5))
      Backburner.configure { |config| config.respond_timeout = 2.5 }
      assert_equal 3, resolve_respond_timeout(nil)
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

    it "supports a fractional retry_delay from a value or a class" do
      assert_equal 2.5, resolve_retry_delay(2.5)
      assert_equal 1.5, resolve_retry_delay(stub(:queue_retry_delay => 1.5))
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
