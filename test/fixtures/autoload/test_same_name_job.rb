module TestOtherNamespace; end
class TestSameNameJob
  OTHER = TestOtherNamespace::TestSameNameJob # NameError for a constant of the same name in another module
  def self.perform(x); end
end
