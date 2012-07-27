require File.expand_path('../test_helper', __FILE__)

module NestedDemo
  class TestJobC
    include Backburner::Queue
    def self.perform(x); puts "Performed #{x} in #{self}"; end
  end

  class TestJobD
    include Backburner::Queue
    def self.perform(x); raise RuntimeError; end
  end
end

describe "Backburner::Job module" do
  describe "for initialize method" do
    before do
      @task_body =  { :class => "NewsletterSender", :args => ["foo@bar.com", "bar@foo.com"] }
      @task = stub(:body => @task_body.to_json, :ttr => 120, :delete => true, :bury => true)
    end

    it "should create job with correct task data" do
      @job = Backburner::Job.new(@task)
      assert_equal @task, @job.task
      assert_equal ["class", "args"], @job.body.keys
      assert_equal @task_body[:class], @job.name
      assert_equal @task_body[:args], @job.args
    end
  end # initialize

  describe "for process method" do
    describe "with valid task" do
      before do
        @task_body =  { :class => "NestedDemo::TestJobC", :args => [56] }
        @task = stub(:body => @task_body.to_json, :ttr => 120, :delete => true, :bury => true)
        @task.expects(:delete).once
        @task.expects(:bury).never
      end

      it "should process task" do
        @job = Backburner::Job.new(@task)
        out = silenced(1) { @job.process }
        assert_match /Performed 56 in NestedDemo::TestJobC/, out
      end # process
    end # valid

    describe "with invalid task" do
      before do
        @task_body =  { :class => "NestedDemo::TestJobD", :args => [56] }
        @task = stub(:body => @task_body.to_json, :ttr => 120, :delete => true, :bury => true)
        @task.expects(:delete).never
        @task.expects(:bury).once
      end

      it "should raise an exception" do
        @job = Backburner::Job.new(@task)
        out = silenced(1) { @job.process }
        assert_match /Exception RuntimeError/, out
      end # error invalid
    end # invalid

    describe "with invalid class" do
      before do
        @task_body =  { :class => "NestedDemo::TestJobY", :args => [56] }
        @task = stub(:body => @task_body.to_json, :ttr => 120, :delete => true, :bury => true)
        @task.expects(:delete).never
      end

      it "should raise an exception" do
        @job = Backburner::Job.new(@task)
        assert_raises(Backburner::Job::JobNotFound) { @job.process }
      end # error class
    end # invalid
  end # process
end