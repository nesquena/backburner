$:.unshift "lib"
require 'backburner'

# Define ruby job
class TestJob
  include Backburner::Queue
  # queue "test-job"

  def self.perform(value, user)
    puts "[TestJob] Running perform with args: [#{value}, #{user}]"
  end
end

# Configure Backburner
Backburner.configure do |config|
  config.beanstalk_url = "beanstalk://127.0.0.1"
  config.tube_namespace = "demo.production"
end

# Enqueue tasks
Backburner.enqueue TestJob, 5, 3
Backburner.enqueue TestJob, 10, 6

# Work tasks using threaded worker
Backburner.work("test-job", :worker => Backburner::Workers::ThreadsOnFork)