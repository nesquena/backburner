$:.unshift "lib"
require 'backburner'

$values = []

# Define ruby job
class TestJob
  include Backburner::Queue
  queue "test-job"

  def self.perform(value)
    puts "[TestJob] Running perform with args: [#{value}]"
    $values << value
    puts "#{$values.size} total jobs processed"
  end
end

# Configure Backburner
Backburner.configure do |config|
  config.beanstalk_url = "beanstalk://127.0.0.1"
  config.tube_namespace = "demo.production"
end

# Enqueue tasks
1.upto(1000) do |i|
  Backburner.enqueue TestJob, i
end

# Work tasks using threaded worker
Backburner.work("test-job", :worker => Backburner::Workers::ThreadsOnFork)