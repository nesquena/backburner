module Backburner
  module Queue
    def self.included(base)
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
          @queue_name || Backburner.configuration.primary_queue
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

      # Returns or assigns queue parallel active jobs limit (only ThreadsOnFork Worker)
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

      # Returns or assigns queue retry limit (only ThreadsOnFork Worker)
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
