$:.unshift "lib"
require 'echelon'

# connection = Echelon::Connection.setup("beanstalk://localhost")

Echelon.configure do |config|
  config.beanstalk_url = "beanstalk://127.0.0.1"
  config.tube_namespace = "myblog.production"
end

# p Echelon.configuration.beanstalk_url

p Echelon::Worker.connection

class TestJob < Echelon::Job
  tube "test.job"

  def initialize(args)
    @value, @user = args['value'], args['user']
  end

  def perform
    puts "Hey"
  end
end

class User
  attr_accessor :id, :name

  def initialize(id, name)
    @id, @name = id, name
  end
end

Echelon::Worker.enqueue TestJob, { :value => 5, :user => User.new(3, "Bob").id }