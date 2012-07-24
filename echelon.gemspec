# -*- encoding: utf-8 -*-
require File.expand_path('../lib/echelon/version', __FILE__)

Gem::Specification.new do |s|
  s.authors       = ["Nathan Esquenazi"]
  s.email         = ["nesquena@gmail.com"]
  s.description   = %q{Beanstalk background job processing made easy}
  s.summary       = %q{Reliable beanstalk background job processing made easy for Ruby and Sinatra}
  s.homepage      = "http://github.com/nesquena/echelon"

  s.files         = `git ls-files`.split($\)
  s.executables   = s.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  s.test_files    = s.files.grep(%r{^(test|spec|features)/})
  s.name          = "echelon"
  s.require_paths = ["lib"]
  s.version       = Echelon::VERSION

  s.add_runtime_dependency(%q<beanstalk-client>, [">= 0"])
  s.add_runtime_dependency(%q<json_pure>, [">= 0"])

  s.add_development_dependency 'rake'
  s.add_development_dependency 'minitest'
  s.add_development_dependency 'mocha'
end
