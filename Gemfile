source 'https://rubygems.org'

# Specify your gem's dependencies in backburner.gemspec
gemspec

# Test against an older Active Job (and the Active Support it needs), as CI does: ACTIVEJOB_VERSION=7.1 bundle install
gem 'activejob', "~> #{ENV['ACTIVEJOB_VERSION']}.0" unless ENV['ACTIVEJOB_VERSION'].to_s.empty?
