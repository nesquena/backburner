$:.unshift "lib"
require 'echelon'

# Define ruby job
class TestJob
  include Echelon::Job
  # queue "test-job"

  def self.perform(value, user)
    puts "[TestJob] Running perform with args: [#{value}, #{user}]"
  end
end

# Configure Echelon
Echelon.configure do |config|
  config.beanstalk_url = "beanstalk://127.0.0.1"
  config.tube_namespace = "demo.production"
end

# Enqueue tasks
Echelon.enqueue TestJob, 5, 3
Echelon.enqueue TestJob, 10, 6

# Work tasks
Echelon.work!("test-job")