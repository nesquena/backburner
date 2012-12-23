require File.expand_path('../../test_helper', __FILE__)
require File.expand_path('../../fixtures/test_jobs', __FILE__)

describe "Backburner::Workers::Forking module" do

  before do
    Backburner.default_queues.clear
    @worker_class = Backburner::Workers::Forking
  end

  describe "for fork_one_job method" do

    it "should fork, reconnect, work job, and exit" do

      clear_jobs!("foo.bar")
      @worker_class.enqueue TestJob, [1, 2], :queue => "foo.bar"

      fake_pid = 45
      Process.expects(:fork).returns(fake_pid) do |&block|
        Connection.expects(:new).with(Backburner.configuration.beanstalk_url)
        @worker_class.any_instance.expects(:work_one_job)
        @worker_class.any_instance.expects(:coolest_exit)
        block.call
      end
      Process.expects(:wait).with(fake_pid)

      silenced(2) do
        worker = @worker_class.new('foo.bar')
        worker.prepare
        worker.fork_one_job
      end
    end

  end # fork_one_job

end
