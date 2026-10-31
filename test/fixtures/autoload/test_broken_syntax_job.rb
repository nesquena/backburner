class TestBrokenSyntaxJob
  def self.perform(x)
    if # a syntax error: SyntaxError while the file loads
  end
