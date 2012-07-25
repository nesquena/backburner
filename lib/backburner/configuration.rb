module Backburner
  class Configuration
    attr_accessor :beanstalk_url      # beanstalk url connection
    attr_accessor :tube_namespace     # namespace prefix for every queue
    attr_accessor :default_priority   # default job priority
    attr_accessor :respond_timeout    # default job timeout
    attr_accessor :on_error           # error handler
    attr_accessor :default_queues     # default queues
    attr_accessor :known_job_classes  # list of known job classes

    def initialize
      @beanstalk_url     = "beanstalk://localhost"
      @tube_namespace    = "unique.jobs"
      @default_priority  = 65536
      @respond_timeout   = 120
      @on_error          = nil
      @default_queues    = []
      @known_job_classes = []
    end
  end # Configuration
end # Backburner