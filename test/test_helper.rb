require 'rubygems'
require 'tempfile'
require 'minitest/autorun'
require 'mocha'
$:.unshift File.expand_path("../../lib")
require 'echelon'

# Configure Echelon
Echelon.configure do |config|
  config.beanstalk_url = "beanstalk://localhost"
  config.tube_namespace = "demo.test"
end

## Kernel Extensions
require 'stringio'

module Kernel
  # Redirect standard out, standard error and the buffered logger for sprinkle to StringIO
  # capture_stdout { any_commands; you_want } => "all output from the commands"
  def capture_stdout
    return yield if ENV['DEBUG'] # Skip if debug mode

    out = StringIO.new
    $stdout = out
    $stderr = out
    yield
    return out.string
  ensure
    $stdout = STDOUT
    $stderr = STDERR
  end
end

class User
  attr_accessor :id, :name

  def initialize(id, name)
    @id, @name = id, name
  end
end

class MiniTest::Spec
  class << self
    alias :should :it
    alias :context :describe
  end
  alias :assert_no_match  :refute_match
  alias :assert_not_nil   :refute_nil
  alias :assert_not_equal :refute_equal

  # assert_same_elements([:a, :b, :c], [:c, :a, :b]) => passes
  def assert_same_elements(a1, a2, msg = nil)
    [:select, :inject, :size].each do |m|
      [a1, a2].each {|a| assert_respond_to(a, m, "Are you sure that #{a.inspect} is an array?  It doesn't respond to #{m}.") }
    end

    assert a1h = a1.inject({}) { |h,e| h[e] ||= a1.select { |i| i == e }.size; h }
    assert a2h = a2.inject({}) { |h,e| h[e] ||= a2.select { |i| i == e }.size; h }

    assert_equal(a1h, a2h, msg)
  end

  # silenced(5) { ... }
  def silenced(time=3, &block)
    Timeout::timeout(time) { capture_stdout(&block) }
  end

  # pop_one_job(tube_name)
  def pop_one_job(tube_name)
    connection = Echelon::Worker.connection
    tube_name = [Echelon.configuration.tube_namespace, tube_name].join(".")
    connection.watch(tube_name)
    connection.list_tubes_watched.each do |server, tubes|
      tubes.each { |tube| connection.ignore(tube) unless tube == tube_name }
    end
    silenced(3) { @res = connection.reserve }
    return @res, JSON.parse(@res.body)
  end
end # MiniTest::Spec