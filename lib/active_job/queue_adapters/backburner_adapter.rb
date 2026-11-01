# Rails' own adapter files require backburner too, for apps that don't require it themselves
require 'backburner' unless defined?(Backburner::Worker)

module ActiveJob
  module QueueAdapters
    # Rails 7.2 added AbstractAdapter; the adapters of older Rails have no superclass
    rails_7_2_or_newer = const_defined?(:AbstractAdapter, false)

    # Explicitly remove the implementation rails' 7.2+ ship. Older rails' keep theirs, unless their autoload
    # loads this file instead (it shadows theirs when this gem's lib comes first on the load path).
    remove_const(:BackburnerAdapter) if rails_7_2_or_newer && const_defined?(:BackburnerAdapter)

    # = Backburner adapter for Active Job
    #
    # To use Backburner set the queue_adapter config to +:backburner+.
    #
    #   Rails.application.config.active_job.queue_adapter = :backburner
    #
    # A job's TTR is its class's +queue_respond_timeout+ when it has one, as for a Backburner::Queue job
    # (+ttr: job.class+ resolves it), else +config.respond_timeout+:
    #
    #   class ReportJob < ApplicationJob
    #     def self.queue_respond_timeout; 3600; end
    #   end
    class BackburnerAdapter < (rails_7_2_or_newer ? ::ActiveJob::QueueAdapters::AbstractAdapter : Object)
      def enqueue(job)
        response = Backburner::Worker.enqueue(JobWrapper, [job.serialize], queue: job.queue_name, pri: job.priority, ttr: job.class)
        job.provider_job_id = response[:id] if response.is_a?(Hash)
        response
      end

      def enqueue_at(job, timestamp)
        delay = timestamp - Time.current.to_f
        response = Backburner::Worker.enqueue(JobWrapper, [job.serialize], queue: job.queue_name, pri: job.priority, delay: delay, ttr: job.class)
        job.provider_job_id = response[:id] if response.is_a?(Hash)
        response
      end

      class JobWrapper
        class << self
          def perform(job_data)
            Base.execute job_data
          end
        end
      end
    end
  end
end
