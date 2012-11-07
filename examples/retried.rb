$:.unshift "lib"
require 'backburner'

$error = 0

class User
  include Backburner::Performable
  attr_accessor :id, :name

  def self.foo(x, y)
    $error += 1
    raise "fail #{$error}" unless $error > 3
    puts "User #foo args [#{x}, #{y}] Success!!"
  end
end

# Configure Backburner
Backburner.configure do |config|
  config.beanstalk_url = "beanstalk://127.0.0.1"
  config.tube_namespace = "demo.production"
  config.on_error = lambda { |e| puts "HEY!!! #{e.class}" }
  config.max_job_retries = 3
  config.retry_delay     = 0
end

# Enqueue tasks
User.async(:queue => "retried").foo("bar", "baz")

# Run work
# Backburner.default_queues << "user"
Backburner.work