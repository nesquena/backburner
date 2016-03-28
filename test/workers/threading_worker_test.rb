require File.expand_path('../../test_helper', __FILE__)
require File.expand_path('../../fixtures/test_forking_jobs', __FILE__)

describe "Backburner::Workers::Threading module" do

  before do
    Backburner.default_queues.clear
    @worker_class = Backburner::Workers::Threading
  end

  describe "for prepare method" do
    it "should make tube names array always unique to avoid duplication" do
      worker = @worker_class.new(["foo", "demo.test.foo"])
      worker.prepare
      assert_equal ["demo.test.foo"], worker.tube_names
    end
  end # prepare
end
