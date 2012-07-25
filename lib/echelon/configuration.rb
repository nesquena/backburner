module Echelon
  # Rabl.host
  class Configuration
    attr_accessor :beanstalk_url
    attr_accessor :tube_namespace
    attr_accessor :default_priority
    attr_accessor :respond_timeout
    attr_accessor :on_error

    def initialize
      @beanstalk_url  = "beanstalk://localhost"
      @tube_namespace = "unique.jobs"
      @default_priority = 65536
      @respond_timeout  = 120
      @on_error = nil
    end
  end # Configuration
end # Echelon