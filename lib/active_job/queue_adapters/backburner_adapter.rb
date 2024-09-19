module ActiveJob
  module QueueAdapters
    # = Backburner adapter for Active Job
    #
    # To use Backburner set the queue_adapter config to +:backburner+.
    #
    #   Rails.application.config.active_job.queue_adapter = :backburner
    class BackburnerAdapter < ::ActiveJob::QueueAdapters::AbstractAdapter
      def enqueue(job)
        response = Backburner::Worker.enqueue(JobWrapper, [job.serialize], queue: job.queue_name, pri: job.priority)
        job.provider_job_id = response[:id] if response.is_a?(Hash)
        response
      end

      def enqueue_at(job, timestamp)
        delay = timestamp - Time.current.to_f
        response = Backburner::Worker.enqueue(JobWrapper, [job.serialize], queue: job.queue_name, pri: job.priority, delay: delay)
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
