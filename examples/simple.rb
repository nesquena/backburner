$:.unshift "lib"
require 'backburner'

class User
  include Backburner::Performable
  attr_accessor :id, :name

  def self.first
    User.find(3, "John")
  end

  def self.find(id, name="Fetched")
    User.new(id, name)
  end

  def initialize(id, name)
    @id, @name = id, name
  end

  def hello(x, y)
    puts "User(id=#{id}) #hello args: [#{x}, #{y}] (Instance method)"
  end

  def self.foo(x, y)
    puts "User #foo args [#{x}, #{y}] (Class method)"
  end
end

# Configure Backburner
Backburner.configure do |config|
  config.beanstalk_url = "beanstalk://127.0.0.1"
  config.tube_namespace = "demo.production"
  config.on_error = lambda { |e| puts "HEY!!! #{e.class}" }
end

# Enqueue tasks
@user = User.first
@user.async(:pri => 1000).hello("foo", "bar")
User.async.foo("bar", "baz")

# Run work
# Backburner.default_queues << "user"
Backburner.work