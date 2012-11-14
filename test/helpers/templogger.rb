class Templogger
  attr_reader :logger, :log_path

  def initialize(root_path)
    @file = Tempfile.new('foo', root_path)
    @log_path = @file.path
    @logger = Logger.new(@log_path)
  end

  # wait_for_match /Completed TestJobFork/m
  def wait_for_match(match_pattern)
    sleep 0.1 until self.body =~ match_pattern
  end

  def body
    File.read(@log_path)
  end

  def close
    @file.close
  end
end