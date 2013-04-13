module Backburner
  class Configuration
    attr_accessor :beanstalk_url      # beanstalk url connection
    attr_accessor :tube_namespace     # namespace prefix for every queue
    attr_accessor :default_priority   # default job priority
    attr_accessor :respond_timeout    # default job timeout
    attr_accessor :on_error           # error handler
    attr_accessor :max_job_retries    # max job retries
    attr_accessor :retry_delay        # retry delay in seconds
    attr_accessor :default_queues     # default queues
    attr_accessor :logger             # logger
    attr_accessor :default_worker     # default worker class
    attr_accessor :connection_type    # connection type class
    attr_accessor :auth               # authentication info

    def initialize
      @beanstalk_url     = "beanstalk://localhost"
      @tube_namespace    = "backburner.worker.queue"
      @default_priority  = 65536
      @respond_timeout   = 120
      @on_error          = nil
      @max_job_retries   = 0
      @retry_delay       = 5
      @default_queues    = []
      @logger            = nil
      @default_worker    = Backburner::Workers::Simple
      @connection_type   = Backburner::Connection
      @auth              = nil
    end
  end # Configuration
end # Backburner