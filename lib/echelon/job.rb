module Echelon
  class Job
    class << self
      attr_reader :tube_name

      # Assigns tube name for this job
      # tube "some.task.name"
      def tube(name)
        @tube_name = name
      end
    end
  end # Job
end # Echelon