require 'rubygems'
require 'tempfile'
require 'minitest/autorun'
require 'mocha'
$:.unshift File.expand_path("../../lib")
require 'echelon'

## Kernel Extensions
require 'stringio'

module Kernel
  # Redirect standard out, standard error and the buffered logger for sprinkle to StringIO
  # capture_stdout { any_commands; you_want } => "all output from the commands"
  def capture_stdout
    return yield if ENV['DEBUG'] # Skip if debug mode

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