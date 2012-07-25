module Echelon
  module Job
    def self.included(base)
      base.send(:include, InstanceMethods)
      base.send(:extend, Echelon::Helpers)
      base.extend ClassMethods
    end

    module InstanceMethods
      # TODO
    end # InstanceMethods

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
end # Echelon