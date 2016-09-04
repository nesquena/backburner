module Backburner
  class Configuration
    PRIORITY_LABELS = { :high => 0, :medium => 100, :low => 200 }

    attr_writer   :beanstalk_url       # beanstalk url connection
    attr_accessor :tube_namespace      # namespace prefix for every queue
    attr_reader   :namespace_separator # namespace separator
    attr_accessor :default_priority    # default job priority
    attr_accessor :respond_timeout     # default job timeout
    attr_accessor :on_error            # error handler
    attr_accessor :max_job_retries     # max job retries
    attr_accessor :max_job_buries      # max job buries (after being kicked)
    attr_accessor :retry_delay         # (minimum) retry delay in seconds
    attr_accessor :retry_delay_proc    # proc to calculate delay (and allow for back-off)
    attr_accessor :default_queues      # default queues
    attr_accessor :logger              # logger
    attr_accessor :default_worker      # default worker class
    attr_accessor :primary_queue       # the general queue
    attr_accessor :priority_labels     # priority labels
    attr_accessor :reserve_timeout     # duration to wait to reserve on a single server

    attr_accessor :connect_timeout
    attr_accessor :read_timeout
    attr_accessor :write_timeout

    def initialize
      @beanstalk_url       = "beanstalk://127.0.0.1"
      @tube_namespace      = "backburner.worker.queue"
      @namespace_separator = "."
      @default_priority    = 65536
      @respond_timeout     = 120
      @on_error            = nil
      @max_job_retries     = 0
      @max_job_buries      = -1 # never dropped
      @retry_delay         = 5
      @retry_delay_proc    = lambda { |min_retry_delay, num_retries| min_retry_delay + (num_retries ** 3) }
      @default_queues      = []
      @logger              = nil
      @default_worker      = Backburner::Workers::Simple
      @primary_queue       = "backburner-jobs"
      @priority_labels     = PRIORITY_LABELS
      @reserve_timeout     = nil
      @connect_timeout     = 5
      @read_timeout        = 10
      @write_timeout       = 5
    end

    def timeout_options
      {
        connect_timeout: @connect_timeout,
        read_timeout:    @read_timeout,
        write_timeout:   @write_timeout
      }
    end

    def namespace_separator=(val)
      raise 'Namespace separator cannot used reserved queue configuration separator ":"' if val == ':'
      @namespace_separator = val
    end

    def beanstalk_url
      Array(@beanstalk_url)
    end
  end # Configuration
end # Backburner
