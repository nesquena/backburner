class TestBrokenRuntimeJob
  raise ArgumentError, "bad config" # an error of another kind while the file loads (ENV.fetch raising KeyError, say)
  def self.perform(x); end
end
