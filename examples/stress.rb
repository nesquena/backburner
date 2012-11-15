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

# Work tasks using threads_on_fork worker
# twitter tube will have 10 threads, garbage after 1000 executions and retry jobs 1 times.
Backburner.work("test-job:10:100:1", :worker => Backburner::Workers::ThreadsOnFork)