require File.expand_path('../test_helper', __FILE__)

$echelon_sum = 0
$echelon_numbers = []

class TestEchelonJob
  include Echelon::Job
  queue "test.jobber"

  def self.perform(value, number)
    $echelon_sum += value
    $echelon_numbers << number
  end
end

describe "Echelon module" do
  before { Echelon.default_queues.clear }

  describe "for enqueue method" do
    before do
      Echelon.enqueue TestEchelonJob, 5, 6
      Echelon.enqueue TestEchelonJob, 15, 10
      silenced(2) do
        worker = Echelon::Worker.new('test.jobber')
        worker.prepare
        2.times { worker.work_one_job }
      end
    end

    it "can run jobs using #run method" do
      assert_equal 20, $echelon_sum
      assert_same_elements [6, 10], $echelon_numbers
    end
  end # enqueue

  describe "for work! method" do
    it "invokes worker start" do
      Echelon::Worker.expects(:start).with(["foo", "bar"])
      Echelon.work!("foo", "bar")
    end
  end # work!

  describe "for configuration" do
    it "remembers the tube_namespace" do
      assert_equal "demo.test", Echelon.configuration.tube_namespace
    end
  end # configuration

  describe "for default_queues" do
    it "supports assignment" do
      Echelon.default_queues << "foo"
      Echelon.default_queues << "bar"
      assert_same_elements ["foo", "bar"], Echelon.default_queues
    end
  end
end # Echelon