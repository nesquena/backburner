require 'fileutils'
require 'tmpdir'

class Templogger
  attr_reader :logger, :log_path

  def initialize(root_path = nil)
    @owned_dir = root_path.nil?
    @dir = root_path || Dir.mktmpdir('backburner-test-')
    @file = Tempfile.new('foo', @dir)
    @log_path = @file.path
    @logger = Logger.new(@log_path)
  rescue
    @file.close! if @file
    FileUtils.remove_entry(@dir) if @owned_dir && @dir && File.exist?(@dir)
    raise
  end

  # wait_for_match /Completed TestJobFork/m
  def wait_for_match(match_pattern)
    sleep 0.1 until self.body =~ match_pattern
  end

  def body
    File.read(@log_path)
  end

  def close
    @logger.close if @logger
    @file.close! # unlink it now: a Tempfile finalizer left for GC calls Process.pid, which some tests mock
  ensure
    FileUtils.remove_entry(@dir) if @owned_dir && @dir && File.exist?(@dir)
  end
end
