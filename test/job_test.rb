require_relative 'test_helper'
require_relative 'fixtures/test_jobs'

module NestedDemo
  class TestJobC
    def self.perform(x); puts "Performed #{x} in #{self}"; end
  end

  class TestJobD
    include Backburner::Queue
    def self.perform(x); raise RuntimeError; end
  end
end

describe "Backburner::Job module" do
  describe "for initialize" do
    describe "with hash" do
      before do
        @task = stub(:body => task_body, :ttr => 120, :delete => true, :bury => true)
      end

      describe "with string keys" do
        let(:task_body) { { "class" => "NewsletterSender", "args" => ["foo@bar.com", "bar@foo.com"] } }
        it "should create job with correct task data" do
          @job = Backburner::Job.new(@task)
          assert_equal @task, @job.task
          assert_equal ["class", "args"], @job.body.keys
          assert_equal task_body["class"], @job.name
          assert_equal task_body["args"], @job.args
        end
      end

      describe "with symbol keys" do
        let(:task_body) { { :class => "NewsletterSender", :args => ["foo@bar.com", "bar@foo.com"] } }
        it "should create job with correct task data" do
          @job = Backburner::Job.new(@task)
          assert_equal @task, @job.task
          assert_equal [:class, :args], @job.body.keys
          assert_equal task_body[:class], @job.name
          assert_equal task_body[:args], @job.args
        end
      end
    end # with hash

    describe "with json string" do
      before do
        @task_body =  { "class" => "NewsletterSender", "args" => ["foo@bar.com", "bar@foo.com"] }
        @task = stub(:body => @task_body.to_json, :ttr => 120, :delete => true, :bury => true)
      end

      it "should create job with correct task data" do
        @job = Backburner::Job.new(@task)
        assert_equal @task, @job.task
        assert_equal ["class", "args"], @job.body.keys
        assert_equal @task_body["class"], @job.name
        assert_equal @task_body["args"], @job.args
      end
    end # with json

    describe "with invalid string" do
      before do
        @task_body =  "^%$*&^*"
        @task = stub(:body => @task_body, :ttr => 120, :delete => true, :bury => true)
      end

      it "should raise a job format exception" do
        assert_raises(Backburner::Job::JobFormatInvalid) {
          @job = Backburner::Job.new(@task)
        }
      end
    end # invalid
  end # initialize

  describe "for process method" do
    describe "with valid task" do
      before do
        @task_body =  { "class" => "NestedDemo::TestJobC", "args" => [56] }
        @task = stub(:body => @task_body, :ttr => 120, :delete => true, :bury => true)
        @task.expects(:delete).once
      end

      it "should process task" do
        @job = Backburner::Job.new(@task)
        out = silenced(1) { @job.process }
        assert_match(/Performed 56 in NestedDemo::TestJobC/, out)
      end # process
    end # valid

    describe "with invalid task" do
      before do
        @task_body =  { "class" => "NestedDemo::TestJobD", "args" => [56] }
        @task = stub(:body => @task_body, :ttr => 120, :delete => true, :bury => true)
        @task.expects(:delete).never
      end

      it "should raise an exception" do
        @job = Backburner::Job.new(@task)
        assert_raises(RuntimeError) { @job.process }
      end # error invalid
    end # invalid

    describe "with invalid class" do
      before do
        @task_body =  { "class" => "NestedDemo::TestJobY", "args" => [56] }
        @task = stub(:body => @task_body, :ttr => 120, :delete => true, :bury => true)
        @task.expects(:delete).never
      end

      it "should raise an exception" do
        @job = Backburner::Job.new(@task)
        assert_raises(Backburner::Job::JobNotFound) { @job.process }
      end # error class
    end # invalid
  end # process

  describe "for simple delegation method" do
    before do
      @task_body =  { "class" => "NestedDemo::TestJobC", "args" => [56] }
      @task = stub(:body => @task_body, :ttr => 120, :delete => true, :bury => true)
      @task.expects(:bury).once
    end

    it "should call bury for task" do
      @job = Backburner::Job.new(@task)
      @job.bury
    end # bury
  end # simple delegation

  describe "timing out for various values of ttr" do
    before do
      @task_body = { "class" => "NestedDemo::TestJobC", "args" => [56] }
    end

    describe "when ttr == 0" do
      it "should use 0 for the timeout" do
        @task = stub(:body => @task_body, :delete => true, :ttr => 0)
        @job = Backburner::Job.new(@task)
        Timeout.expects(:timeout).with(0)
        @job.process
      end
    end

    describe "when ttr == 1" do
      it "should use 1 for the timeout" do
        @task = stub(:body => @task_body, :delete => true, :ttr => 1)
        @job = Backburner::Job.new(@task)
        Timeout.expects(:timeout).with(1)
        @job.process
      end
    end

    describe "when ttr > 1" do
      it "should use ttr-1 for the timeout" do
        @task = stub(:body => @task_body, :delete => true, :ttr => 2)
        @job = Backburner::Job.new(@task)
        Timeout.expects(:timeout).with(1)
        @job.process
      end
    end
  end

  describe 'for finding job with id' do
    before do
      job = Backburner::Worker.enqueue TestPlainJob, [7, 9]
      @job_id = job[:id].to_i
    end

    describe 'with invalid job id' do
      it 'raises an exception' do
        invalid_job_id = @job_id + 41
        assert_raises(Backburner::Job::JobNotFound) { Backburner::Job.find_by_id(invalid_job_id) }
      end
    end

    describe 'with valid job id' do
      it 'returns job as enqueued' do
        job = Backburner::Job.find_by_id(@job_id)
        job_body = JSON.parse(job.body)
        assert_equal "TestPlainJob", job_body['class']
        assert_equal [7, 9], job_body['args']
        assert_equal @job_id, job.id.to_i
      end
    end
  end

  describe 'for cancelling job with id' do
    before do
      job = Backburner::Worker.enqueue TestPlainJob, [7, 9]
      @job_id = job[:id].to_i
    end

    describe 'with invalid job id' do
      it 'raises an exception' do
        invalid_job_id = @job_id + 2000
        assert_raises(Backburner::Job::JobNotFound) { Backburner::Job.cancel invalid_job_id }
      end
    end

    describe 'with valid job id' do
      it 'returns status deleted upon cancellation' do
        response = Backburner::Job.cancel(@job_id)
        assert_equal 'DELETED', response[:status]
      end

      it 'cannot find job after cancelation' do
        Backburner::Job.cancel(@job_id)
        assert_raises(Backburner::Job::JobNotFound) { Backburner::Job.find_by_id @job_id }
      end
    end
  end
end
