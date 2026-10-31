require 'backburner_test_missing_gem' # a gem left out of the bundle: LoadError while the file loads
class TestBrokenRequireJob
  def self.perform(x); end
end
