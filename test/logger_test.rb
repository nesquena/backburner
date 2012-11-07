require File.expand_path('../test_helper', __FILE__)

describe "Backburner::Logger module" do
  include Backburner::Logger

  before do
    @strio = StringIO.new
    @logger = Logger.new(@strio)
  end

  describe "for log_info method" do
    it "prints out to std out" do
      output = capture_stdout { log_info("foo") }
      assert_equal "foo\n", output
    end

    it "can be configured to log to logger" do
      Backburner.configure { |config| config.logger = @logger }
      log_info("foo")
      assert_match /I,.*?foo/, @strio.string
    end

    after do
      Backburner.configure { |config| config.logger = nil }
    end
  end # log_info

  describe "for log_error method" do
    it "prints out to std err" do
      output = capture_stdout { log_error("bar") }
      assert_equal "bar\n", output
    end

    it "can be configured to log to logger" do
      Backburner.configure { |config| config.logger = @logger }
      log_error("bar")
      assert_match /E,.*?bar/, @strio.string
    end

    after do
      Backburner.configure { |config| config.logger = nil }
    end
  end # log_error
end