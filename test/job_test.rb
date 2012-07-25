require File.expand_path('../test_helper', __FILE__)

module NestedDemo
  class TestJobA; include Echelon::Job; end
  class TestJobB; include Echelon::Job; end
end

describe "Echelon::Job module" do
  describe "for queue method accessor" do
    it "should return the queue name" do
      assert_equal "nested-demo/test-job-a", NestedDemo::TestJobA.queue
    end
  end # queue_name

  describe "for queue assignment method" do
    it "should allow queue name to be assigned" do
      NestedDemo::TestJobB.queue("nested/job")
      assert_equal "nested/job", NestedDemo::TestJobB.queue
    end
  end # queue
end # Echelon::Job