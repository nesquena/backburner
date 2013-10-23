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
    end # ClassMethods
  end # Queue
end # Backburner