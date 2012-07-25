$:.unshift "lib"
require 'backburner'

module Tester
  class TestJob
    include Backburner::Queue
    queue "test.job"

    def self.perform(value, user)
      p [value, user]
    end
  end

  class UserModel
    include Backburner::Performable

    attr_accessor :id, :name

    def self.first
      self.find(3, "John")
    end

    def self.find(id, name="Fetched")
      self.new(id, name)
    end

    def initialize(id, name)
      @id, @name = id, name
    end

    def hello(x, y)
      puts "Instance #{x} and #{y} and my id is #{id}"
    end

    def self.foo(x, y)
      puts "Class #{x} and #{y}"
    end
  end
end

# connection = Backburner::Connection.new("beanstalk://localhost")

Backburner.configure do |config|
  config.beanstalk_url = "beanstalk://127.0.0.1"
  config.tube_namespace = "myblog.production"
end

# p Backburner.configuration.beanstalk_url
# p Backburner::Worker.connection

Backburner.enqueue Tester::TestJob, 5, 3
Backburner.enqueue Tester::TestJob, 10, 6
@user = Tester::UserModel.first
@user.async.hello("foo", "bar")
Tester::UserModel.async.foo("bar", "baz")

Backburner.default_queues.concat([Tester::TestJob.queue, Tester::UserModel.queue])
Backburner.work
# Backburner.work("test.job")
# Backburner.work("tester/user-model")