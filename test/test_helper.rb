require 'rubygems'
require 'tempfile'
require 'minitest/autorun'
require 'mocha/minitest'

$LOAD_PATH.unshift File.expand_path("lib")
require 'backburner'
require File.expand_path('../helpers/templogger', __FILE__)

# Configure Backburner
Backburner.configure do |config|
  config.beanstalk_url = "beanstalk://127.0.0.1"
  config.tube_namespace = "demo.test"
end

## Kernel Extensions
require 'stringio'

module Kernel
  # Redirect standard out, standard error and the buffered logger for sprinkle to StringIO
  # capture_stdout { any_commands; you_want } => "all output from the commands"
  def capture_stdout
    if ENV['DEBUG'] # Skip if debug mode
      yield
      return ""
    end

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

  #   assert_contains(['a', '1'], /\d/) => passes
  #   assert_contains(['a', '1'], 'a') => passes
  #   assert_contains(['a', '1'], /not there/) => fails
  def assert_contains(collection, x, extra_msg = "")
    collection = [collection] unless collection.is_a?(Array)
    msg = "#{x.inspect} not found in #{collection.to_a.inspect} #{extra_msg}"
    case x
    when Regexp
      assert(collection.detect { |e| e =~ x }, msg)
    else
      assert(collection.include?(x), msg)
    end
  end

  # silenced(5) { ... }
  def silenced(time=3, &block)
    Timeout::timeout(time) { capture_stdout(&block) }
  end

  def beanstalk_connection
    Backburner::Connection.new(Backburner.configuration.beanstalk_url)
  end

  # pop_one_job(tube_name)
  def pop_one_job(tube_name=Backburner.configuration.primary_queue)
    tube_name  = [Backburner.configuration.tube_namespace, tube_name].join(".")
    connection = beanstalk_connection
    connection.tubes.watch!(tube_name)
    silenced(3) { @res = connection.tubes.reserve }
    yield @res, Backburner.configuration.job_parser_proc.call(@res.body)
  ensure
    connection.close if connection
  end

  # clear_jobs!('foo')
  def clear_jobs!(*tube_names)
    connection = beanstalk_connection
    tube_names.each do |tube_name|
      expanded_name = [Backburner.configuration.tube_namespace, tube_name].join(".")
      connection.tubes.find(expanded_name).clear
    end
  ensure
    connection.close if connection
  end

  # A beanstalkd of the test's own (on @port) that it can stop and start, for outage tests:
  # pick_beanstalkd_port in `before`, then start_beanstalkd, and stop_beanstalkd in `after`
  def pick_beanstalkd_port
    @beanstalkd_bin = ENV['BEANSTALKD_BIN'] || ENV['PATH'].split(File::PATH_SEPARATOR).
      map { |dir| File.join(dir, 'beanstalkd') }.find { |file| File.executable?(file) }
    skip "needs a beanstalkd binary on PATH or in BEANSTALKD_BIN" unless @beanstalkd_bin
    server = TCPServer.new('127.0.0.1', 0)
    @port = server.addr[1]
    server.close
  end

  def start_beanstalkd
    @beanstalkd_pid = Process.spawn(@beanstalkd_bin, '-l', '127.0.0.1', '-p', @port.to_s, [:out, :err] => File::NULL)
    wait_for { (TCPSocket.new('127.0.0.1', @port).close; true) rescue false }
  end

  def stop_beanstalkd
    return unless @beanstalkd_pid
    Process.kill(:KILL, @beanstalkd_pid)
    Process.wait(@beanstalkd_pid)
    @beanstalkd_pid = nil
  end

  def wait_for(seconds = 15)
    deadline = Time.now + seconds
    sleep 0.1 until yield || Time.now > deadline
  end

  # Simulates a broken connection for any Beaneater::Connection. Will
  # simulate a restored connection after `reconnects_after`. This is expected
  # to be used when ensuring a Beaneater connection is open, therefore
  def simulate_disconnect(connection, reconnects_after = 2)
    connection.beanstalk.connection.connection.expects(:closed? => true)
    returns = Array.new(reconnects_after - 1, stub('TCPSocket'))
    returns.each do |socket|
      result = (socket != returns.last)
      socket.stubs(:closed? => result)
    end
    TCPSocket.expects(:new).times(returns.size).returns(*returns)
  end

  # Whether a forked child's GC was disabled by the time the interpreter tore it down (when its
  # at_exit handlers run). Yields the child's body, which ends as `how` says (:return, :raise, or
  # :shutdown, which calls Kernel.exit as the TERM and INT traps do); the block forks a child that
  # runs it and waits for the child.
  def gc_disabled_at_child_exit?(worker, how)
    reader, writer = IO.pipe
    yield(lambda do
      reader.close
      $stdout.reopen(File::NULL)
      $stderr.reopen(File::NULL)
      at_exit { writer.write(GC.disable ? "disabled" : "enabled"); writer.close }
      case how
      when :raise then raise "the child failed"
      when :shutdown then worker.shutdown
      end
    end)
    writer.close
    reader.read == "disabled"
  ensure
    reader.close unless reader.closed?
    writer.close unless writer.closed?
  end
end # MiniTest::Spec
