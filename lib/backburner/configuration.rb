module Backburner
  class Configuration
    attr_accessor :beanstalk_url      # beanstalk url connection
    attr_accessor :tube_namespace     # namespace prefix for every queue
    attr_accessor :default_priority   # default job priority
    attr_accessor :respond_timeout    # default job timeout
    attr_accessor :on_error           # error handler
    attr_accessor :default_queues     # default queues
    attr_accessor :logger             # logger

    def initialize
      @beanstalk_url     = "beanstalk://localhost"
      @tube_namespace    = "backburner.worker.queue"
      @default_priority  = 65536
      @respond_timeout   = 120
      @on_error          = nil
      @default_queues    = []
      @logger            = nil
    end
  end # Configuration
end # Backburner