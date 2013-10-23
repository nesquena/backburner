require File.expand_path('../test_helper', __FILE__)

module NestedDemo
  class TestJobA; include Backburner::Queue; end
  class TestJobB; include Backburner::Queue; end
end

describe "Backburner::Queue module" do
  describe "contains known_queue_classes" do
    it "has all defined known queues" do
      assert_contains Backburner::Worker.known_queue_classes, NestedDemo::TestJobA
      assert_contains Backburner::Worker.known_queue_classes, NestedDemo::TestJobB
    end
  end

  describe "for queue method accessor" do
    it "should return the queue name" do
      assert_equal Backburner.configuration.primary_queue, NestedDemo::TestJobA.queue
    end
  end # queue_name

  describe "for queue assignment method" do
    it "should allow queue name to be assigned" do
      NestedDemo::TestJobB.queue("nested/job")
      assert_equal "nested/job", NestedDemo::TestJobB.queue
    end
  end # queue

  describe "for queue_priority assignment method" do
    it "should allow queue priority to be assigned" do
      NestedDemo::TestJobB.queue_priority(1000)
      assert_equal 1000, NestedDemo::TestJobB.queue_priority
    end
  end # queue_priority

  describe "for queue_respond_timeout assignment method" do
    it "should allow queue respond_timeout to be assigned" do
      NestedDemo::TestJobB.queue_respond_timeout(300)
      assert_equal 300, NestedDemo::TestJobB.queue_respond_timeout
    end
  end # queue_respond_timeout
end # Backburner::Queue