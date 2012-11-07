require 'delegate'

module Backburner
  class Connection < SimpleDelegator
    class BadURL < RuntimeError; end

    attr_accessor :url, :beanstalk

    # Constructs a backburner connection
    # `url` can be a string i.e 'localhost:3001' or an array of addresses.
    def initialize(url)
      @url = url
      connect!
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
end # Backburner