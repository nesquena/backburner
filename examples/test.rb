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

  class User
    include Echelon::Performable

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
@user = Tester::User.first
@user.async(:hello, "foo", "bar")
Tester::User.async(:foo, "bar", "baz")

# Echelon.work!
# Echelon.work!("test.job")
# Echelon.work!("tester/user-hello", "tester/user-foo")