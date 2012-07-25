require File.expand_path('../test_helper', __FILE__)

class TestJob
  include Echelon::Job
end

describe "Echelon::Job module" do
  describe "for queue_name method" do
    it "should return the queue name" do
      TestJob.queue(nil)
      assert_equal "test-job", TestJob.queue_name
    end
  end # queue_name

  describe "for queue assignment method" do
    it "should allow queue name to be assigned" do
      TestJob.queue("test-job")
      assert_equal "test-job", TestJob.queue_name
    end
  end # queue
end # Echelon::Job