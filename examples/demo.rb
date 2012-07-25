$:.unshift "lib"
require 'echelon'

module Tester
  class TestJob
    include Echelon::Job
    queue "test.job"

    def self.perform(value, user)
      p [value, user]
    end
  end

  class UserModel
    include Echelon::Performable

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

# connection = Echelon::Connection.new("beanstalk://localhost")

Echelon.configure do |config|
  config.beanstalk_url = "beanstalk://127.0.0.1"
  config.tube_namespace = "myblog.production"
end

# p Echelon.configuration.beanstalk_url
# p Echelon::Worker.connection

Echelon.enqueue Tester::TestJob, 5, 3
Echelon.enqueue Tester::TestJob, 10, 6
@user = Tester::UserModel.first
@user.async.hello("foo", "bar")
Tester::UserModel.async.foo("bar", "baz")

Echelon.default_queues.concat([Tester::TestJob.queue, Tester::UserModel.queue])
Echelon.work!
# Echelon.work!("test.job")
# Echelon.work!("tester/user-model")