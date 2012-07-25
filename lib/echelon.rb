require 'beanstalk-client'
require 'json'
require 'uri'
require 'timeout'
require 'echelon/version'
require 'echelon/helpers'
require 'echelon/configuration'
require 'echelon/logger'
require 'echelon/connection'
require 'echelon/performable'
require 'echelon/worker'
require 'echelon/job'

module Echelon
  class << self

    # Enqueues a job to be performed with arguments
    # Echelon.enqueue NewsletterSender, self.id, user.id
    def enqueue(job_class, *args)
      Echelon::Worker.enqueue(job_class, args, {})
    end

    # Begins working on jobs enqueued with optional tubes specified
    # Echelon.work!('newsletter_sender', 'test_job')
    def work!(*tubes)
      tubes = tubes.first if tubes.size == 1 && tubes.first.is_a?(Array)
      Echelon::Worker.start(tubes)
    end

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

    # Returns the queues that are processed by default if none are specified
    # default_queues << "foo"
    # default_queues => ["foo", "bar"]
    def default_queues
      configuration.default_queues
    end
  end
end
