module Backburner
  module Queue
    def self.included(base)
      base.send(:extend, Backburner::Helpers)
      base.extend ClassMethods
      Backburner::Worker.known_queue_classes << base
    end

    module ClassMethods
      # Returns or assigns queue name for this job
      # queue "some.task.name"
      # queue => "some.task.name"
      def queue(name=nil)
        if name
          @queue_name = name
        else # accessor
          @queue_name || dasherize(self.name)
        end
      end
    end # ClassMethods
  end # Job
end # Backburner