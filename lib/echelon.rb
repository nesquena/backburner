require 'beanstalk-client'
require 'json'
require 'uri'
require 'timeout'
require 'echelon/version'
require 'echelon/configuration'
require 'echelon/connection'
require 'echelon/worker'
require 'echelon/job'

module Echelon
  class << self
    # Yields a configuration block
    # Echelon.configure do |config|
    #  config.beanstalk_url = "beanstalk://..."
    # end
    def configure(&block)
      yield(configuration)
      configuration
    end

    # Returns the configuration options set for Echelon
    # Echelon.configuration.beanstalk_url => false
    def configuration
      @_configuration ||= Configuration.new
    end

    # Resets the Echelon configuration back to the defaults.
    def reset_configuration!
      @_configuration = nil
    end
  end
end
