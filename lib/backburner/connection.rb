require 'delegate'

module Backburner
  class Connection < SimpleDelegator
    class BadURL < RuntimeError; end

    attr_accessor :url, :beanstalk

    # Constructs a backburner connection
    # `url` can be a string i.e 'localhost:3001' or an array of addresses.
    def initialize(url, opts={})
      @url  = url
      @opts = opts
      connect!
    end

    # True if connected to IronMQ
    def iron_mq?
      false
    end

    # Sets the delegator object to the underlying beaneater pool
    # self.put(...)
    def __getobj__
      __setobj__(@beanstalk)
      super
    end

    protected

    # Connects to a beanstalk queue
    def connect!
      @beanstalk ||= Beaneater::Pool.new(beanstalk_addresses)
    end

    # Returns the beanstalk queue addresses
    #
    # @example
    #   beanstalk_addresses => ["localhost:11300"]
    #
    def beanstalk_addresses
      uris = self.url.is_a?(Array) ? self.url : self.url.split(/[\s,]+/)
      uris.map { |uri| beanstalk_host_and_port(uri) }
    end

    # Returns a host and port based on the uri_string given
    #
    # @example
    #   beanstalk_host_and_port("beanstalk://localhost") => "localhost:11300"
    #
    def beanstalk_host_and_port(uri_string)
      uri = URI.parse(uri_string)
      raise(BadURL, uri_string) if uri.scheme != 'beanstalk'
      "#{uri.host}:#{uri.port || 11300}"
    end
  end # Connection

  class IronMQConnection < Connection
    def iron_mq?
      true
    end

    protected

    def connect!
      unless @beanstalk
        @beanstalk = Beaneater::Pool.new(beanstalk_addresses)
        authenticate! if @opts[:auth]
      end
      @beanstalk
    end

    def authenticate!
      auth = "oauth #{@opts[:auth][:token]} #{@opts[:auth][:project_id]}"
      @beanstalk.transmit_to_all("put 0 0 0 #{auth.length}\r\n#{auth}")
    end
  end # IronMQConnection
end # Backburner