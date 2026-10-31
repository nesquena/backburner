require 'beaneater'
require 'json'
require 'uri'
require 'timeout'
require 'backburner/version'
require 'backburner/helpers'
require 'backburner/configuration'
require 'backburner/logger'
require 'backburner/connection'
require 'backburner/enqueue_pool'
require 'backburner/hooks'
require 'backburner/performable'
require 'backburner/worker'
require 'backburner/workers/simple'
require 'backburner/workers/forking'
require 'backburner/workers/threads_on_fork'
require 'backburner/workers/threading'
require 'backburner/queue'
# On Rails 7.2+ (which added AbstractAdapter) use this gem's Active Job adapter; older Rails autoload theirs.
# Not when Rails' autoload has already loaded the adapter or is loading it (an adapter file requires backburner).
if defined?(ActiveJob::QueueAdapters::AbstractAdapter) && (ActiveJob::QueueAdapters.autoload?(:BackburnerAdapter) ||
   !ActiveJob::QueueAdapters.constants(false).include?(:BackburnerAdapter))
  require 'active_job/queue_adapters/backburner_adapter'
end

module Backburner
  class << self

    # Enqueues a job to be performed with given arguments.
    #
    # @example
    #   Backburner.enqueue NewsletterSender, self.id, user.id
    #
    def enqueue(job_class, *args)
      Backburner::Worker.enqueue(job_class, args, {})
    end

    # Begins working on jobs enqueued with optional tubes specified
    #
    # @example
    #   Backburner.work('newsletter_sender', 'test_job')
    #   Backburner.work('newsletter_sender', 'test_job', :worker => NotSimpleWorker)
    #
    def work(*tubes)
      options = tubes.last.is_a?(Hash) ? tubes.pop : {}
      worker_class = options[:worker] || configuration.default_worker
      worker_class.start(tubes)
    end

    # Yields a configuration block
    #
    # @example
    #   Backburner.configure do |config|
    #     config.beanstalk_url = "beanstalk://..."
    #   end
    #
    def configure(&block)
      yield(configuration)
      configuration
    end

    # Returns the configuration options set for Backburner
    #
    # @example
    #   Backburner.configuration.beanstalk_url => false
    #
    def configuration
      @_configuration ||= Configuration.new
    end

    # Returns the queues that are processed by default if none are specified
    #
    # @example
    #   Backburner.default_queues << "foo"
    #   Backburner.default_queues => ["foo", "bar"]
    #
    def default_queues
      configuration.default_queues
    end
  end
end
