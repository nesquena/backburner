module Backburner
  module Queue
    def self.included(base)
      base.instance_variable_set(:@queue_name, nil)
      base.instance_variable_set(:@queue_priority, nil)
      base.instance_variable_set(:@queue_respond_timeout, nil)
      base.instance_variable_set(:@queue_max_job_retries, nil)
      base.instance_variable_set(:@queue_retry_delay, nil)
      base.instance_variable_set(:@queue_retry_delay_proc, nil)
      base.instance_variable_set(:@queue_jobs_limit, nil)
      base.instance_variable_set(:@queue_garbage_limit, nil)
      base.instance_variable_set(:@queue_retry_limit, nil)
      base.extend ClassMethods
      Backburner::Worker.known_queue_classes << base
    end

    module ClassMethods
      # Returns or assigns queue name for this job.
      #
      # @example
      #   queue "some.task.name"
      #   @klass.queue # => "some.task.name"
      #
      def queue(name=nil)
        if name
          @queue_name = name
        else # accessor
          (@queue_name.is_a?(Proc) ? @queue_name.call(self) : @queue_name) || Backburner.configuration.primary_queue
        end
      end

      # Returns or assigns queue priority for this job
      #
      # @example
      #   queue_priority 120
      #   @klass.queue_priority # => 120
      #
      def queue_priority(pri=nil)
        if pri
          @queue_priority = pri
        else # accessor
          @queue_priority
        end
      end

      # Returns or assigns queue respond_timeout for this job
      #
      # @example
      #   queue_respond_timeout 120
      #   @klass.queue_respond_timeout # => 120
      #
      def queue_respond_timeout(ttr=nil)
        if ttr
          @queue_respond_timeout = ttr
        else # accessor
          @queue_respond_timeout
        end
      end

      # Returns or assigns queue max_job_retries for this job
      #
      # @example
      #   queue_max_job_retries 120
      #   @klass.queue_max_job_retries # => 120
      #
      def queue_max_job_retries(delay=nil)
        if delay
          @queue_max_job_retries = delay
        else # accessor
          @queue_max_job_retries
        end
      end

      # Returns or assigns queue retry_delay for this job
      #
      # @example
      #   queue_retry_delay 120
      #   @klass.queue_retry_delay # => 120
      #
      def queue_retry_delay(delay=nil)
        if delay
          @queue_retry_delay = delay
        else # accessor
          @queue_retry_delay
        end
      end

      # Returns or assigns queue retry_delay_proc for this job
      #
      # @example
      #   queue_retry_delay_proc lambda { |min_retry_delay, num_retries| min_retry_delay + (num_retries ** 2) }
      #   @klass.queue_retry_delay_proc # => lambda { |min_retry_delay, num_retries| min_retry_delay + (num_retries ** 2) }
      #
      def queue_retry_delay_proc(proc=nil)
        if proc
          @queue_retry_delay_proc = proc
        else # accessor
          @queue_retry_delay_proc
        end
      end

      # Returns or assigns queue parallel active jobs limit (only ThreadsOnFork and Threading workers)
      #
      # @example
      #   queue_jobs_limit 5
      #   @klass.queue_jobs_limit # => 5
      #
      def queue_jobs_limit(limit=nil)
        if limit
          @queue_jobs_limit = limit
        else #accessor
          @queue_jobs_limit
        end
      end

      # Returns or assigns queue jobs garbage limit (only ThreadsOnFork Worker)
      #
      # @example
      #   queue_garbage_limit 1000
      #   @klass.queue_garbage_limit # => 1000
      #
      def queue_garbage_limit(limit=nil)
        if limit
          @queue_garbage_limit = limit
        else #accessor
          @queue_garbage_limit
        end
      end

      # Returns or assigns queue retry limit (only ThreadsOnFork worker)
      #
      # @example
      #   queue_retry_limit 6
      #   @klass.queue_retry_limit # => 6
      #
      def queue_retry_limit(limit=nil)
        if limit
          @queue_retry_limit = limit
        else #accessor
          @queue_retry_limit
        end
      end
    end # ClassMethods
  end # Queue
end # Backburner
