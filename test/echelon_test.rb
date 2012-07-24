require File.expand_path('../test_helper', __FILE__)

$foo = 0
$users = []
class TestJob < Echelon::Job
  tube "test.job"

  def initialize(args)
    @value, @user = args['value'], args['user']
  end

  def perform
    $foo += @value
    $users << @user
  end
end

describe "echelon module" do
  before do
    Echelon::Worker.enqueue TestJob, { :value => 5, :user => User.new(3, "Bob") }
    Echelon::Worker.enqueue TestJob, { :value => 6, :user => User.new(4, "Frank") }
  end

  it "can run jobs using #run method" do
    assert_equal 11, $foo
    assert_equal [3, 4], $users.map(&:id)
  end
end