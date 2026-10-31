class TestBrokenNameJob
  include TestMissingConcern # renamed or removed: NameError for another constant while the file loads
  def self.perform(x); end
end
