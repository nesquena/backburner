# -*- encoding: utf-8 -*-
require File.expand_path('../lib/backburner/version', __FILE__)

Gem::Specification.new do |s|
  s.authors       = ["Nathan Esquenazi"]
  s.email         = ["nesquena@gmail.com"]
  s.description   = %q{Beanstalk background job processing made easy}
  s.summary       = %q{Reliable beanstalk background job processing made easy for Ruby and Sinatra}
  s.homepage      = "http://github.com/nesquena/backburner"

  s.files         = `git ls-files`.split($\)
  s.executables   = s.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  s.test_files    = s.files.grep(%r{^(test|spec|features)/})
  s.name          = "backburner"
  s.require_paths = ["lib"]
  s.version       = Backburner::VERSION

  s.add_dependency 'beanstalk-client', "~> 1.1"
  s.add_dependency 'celluloid', '~> 0.11.1'
  s.add_dependency 'dante', '~> 0.1.5'
  s.add_dependency 'json_pure', '>= 1.7.3'

  s.add_development_dependency 'rake'
  s.add_development_dependency 'minitest'
  s.add_development_dependency 'mocha'
end
