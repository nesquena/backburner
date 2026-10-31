class TestBrokenNoMethodJob
  queue_respond_timout 30 # a typo: NoMethodError while the file loads
  def self.perform(x); end
end
