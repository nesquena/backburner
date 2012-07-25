module Echelon
  module Job
    def self.included(base)
      base.send(:include, InstanceMethods)
      base.send(:extend, Echelon::Helpers)
      base.extend ClassMethods
    end

    module InstanceMethods
      # TODO
    end

    module ClassMethods
      # Assigns queue name for this job
      # tube "some.task.name"
      def queue(name)
        @queue_name = name
      end

      # Returns queue_name with proper tube namespace
      def queue_name
        name = @queue_name || dasherize(self.name)
      end
    end
  end # Job
end # Echelon