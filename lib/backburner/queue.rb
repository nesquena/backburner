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
          @queue_name || Backburner.configuration.general_queue
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
    end # ClassMethods
  end # Queue
end # Backburner