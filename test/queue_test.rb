require File.expand_path('../test_helper', __FILE__)

module NestedDemo
  class TestJobA; include Backburner::Queue; end
  class TestJobB; include Backburner::Queue; end
end

module InheritDemo
  class ParentJob
    include Backburner::Queue
    queue "inherit-parent"
    queue_priority 10
    queue_respond_timeout 77
    queue_max_job_retries 4
    queue_retry_delay 9
    queue_retry_delay_proc lambda { |min_retry_delay, num_retries| 42 }
    queue_jobs_limit 3
    queue_garbage_limit 50
    queue_retry_limit 6
  end
  class ChildJob < ParentJob; end
  class GrandchildJob < ChildJob; end
  class OverrideJob < ParentJob
    queue "inherit-override"
    queue_priority 20
  end
  class ReincludedJob < ParentJob; include Backburner::Queue; end
  class LambdaParentJob
    include Backburner::Queue
    queue lambda { |klass| klass.name }
  end
  class LambdaChildJob < LambdaParentJob; end
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

    it "should allow lambdas" do
      NestedDemo::TestJobB.queue(lambda { |klass| klass.name })
      assert_equal "NestedDemo::TestJobB", NestedDemo::TestJobB.queue
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

  describe "for queue_max_job_retries assignment method" do
    it "should allow queue max_job_retries to be assigned" do
      NestedDemo::TestJobB.queue_max_job_retries(5)
      assert_equal 5, NestedDemo::TestJobB.queue_max_job_retries
    end
  end # queue_max_job_retries

  describe "for queue_retry_delay assignment method" do
    it "should allow queue retry_delay to be assigned" do
      NestedDemo::TestJobB.queue_retry_delay(300)
      assert_equal 300, NestedDemo::TestJobB.queue_retry_delay
    end
  end # queue_retry_delay

  describe "for queue_retry_delay_proc assignment method" do
    it "should allow queue retry_delay_proc to be assigned" do
      retry_delay_proc = lambda { |x, y| x - y }
      NestedDemo::TestJobB.queue_retry_delay_proc(retry_delay_proc)
      assert_equal retry_delay_proc.call(2, 1), NestedDemo::TestJobB.queue_retry_delay_proc.call(2, 1)
    end
  end # queue_retry_delay_proc

  describe "for subclasses" do
    settings = [:queue, :queue_priority, :queue_respond_timeout, :queue_max_job_retries, :queue_retry_delay,
                :queue_retry_delay_proc, :queue_jobs_limit, :queue_garbage_limit, :queue_retry_limit]

    it "inherits every queue setting from the superclass" do
      settings.each do |setting|
        refute_nil InheritDemo::ParentJob.send(setting), setting
        assert_equal InheritDemo::ParentJob.send(setting), InheritDemo::ChildJob.send(setting), setting
        assert_equal InheritDemo::ParentJob.send(setting), InheritDemo::GrandchildJob.send(setting), setting
      end
    end

    it "uses its own settings over inherited ones without changing the superclass" do
      assert_equal "inherit-override", InheritDemo::OverrideJob.queue
      assert_equal 20, InheritDemo::OverrideJob.queue_priority
      assert_equal 77, InheritDemo::OverrideJob.queue_respond_timeout
      assert_equal "inherit-parent", InheritDemo::ParentJob.queue
      assert_equal 10, InheritDemo::ParentJob.queue_priority
    end

    it "inherits the superclass settings when it includes Backburner::Queue again" do
      assert_equal "inherit-parent", InheritDemo::ReincludedJob.queue
      assert_equal 10, InheritDemo::ReincludedJob.queue_priority
    end

    it "calls an inherited queue lambda with the subclass" do
      assert_equal "InheritDemo::LambdaChildJob", InheritDemo::LambdaChildJob.queue
    end

    it "registers subclasses as known queue classes, once each" do
      [InheritDemo::ChildJob, InheritDemo::GrandchildJob, InheritDemo::OverrideJob, InheritDemo::ReincludedJob].each do |klass|
        assert_equal 1, Backburner::Worker.known_queue_classes.count(klass), klass.name
      end
    end
  end # subclasses
end # Backburner::Queue
