class TestBrokenTimeoutJob
  raise Timeout::Error, "class body call timed out" # a call in the class body that timed out (Net::OpenTimeout is a Timeout::Error)
  def self.perform(x); end
end
