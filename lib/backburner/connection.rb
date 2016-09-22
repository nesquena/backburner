require 'delegate'

module Backburner
  class Connection
    class BadURL < RuntimeError; end

    attr_accessor :url, :beanstalk

    # If a proc is provided, it will be called (and given this connection as an
    # argument) whenever the connection is reconnected.
    # @example
    #   connection.on_reconnect = lambda { |conn| puts 'reconnected!' }
    attr_accessor :on_reconnect

    # Constructs a backburner connection
    # `url` can be a string i.e '127.0.0.1:3001' or an array of
    # addresses (however, only the first element in the array will
    # be used)
    def initialize(url, options = {}, &on_reconnect)
      @url = url
      @beanstalk = nil
      @on_reconnect = on_reconnect
      @options = options
      connect!
    end

    # Close the connection, if it exists
    def close
      @beanstalk.close if @beanstalk
      @beanstalk = nil
    end

    # Determines if the connection to Beanstalk is currently open
    def connected?
      begin
        !!(@beanstalk && @beanstalk.connection && @beanstalk.connection.connection && !@beanstalk.connection.connection.closed?) # Would be nice if beaneater provided a connected? method
      rescue
        false
      end
    end

    # Attempt to reconnect to Beanstalk. Note: the connection will not be watching
    # or using the tubes it was before it was reconnected (as it's actually a
    # completely new connection)
    # @raise [Beaneater::NotConnected] If beanstalk fails to connect
    def reconnect!
      close
      connect!
      @on_reconnect.call(self) if @on_reconnect.respond_to?(:call)
    end

    # Yield to a block that will be retried several times if the connection to
    # beanstalk goes down and is able to be re-established.
    #
    # @param options Hash Options. Valid options are:
    #   :max_retries       Integer The maximum number of times the block will be yielded to.
    #                              Defaults to 4
    #   :on_retry          Proc    An optional proc that will be called for each retry. Will be
    #                              called after the connection is re-established and :retry_delay
    #                              has passed but before the block is yielded to again
    #   :retry_delay       Float   The amount to sleep before retrying. Defaults to 1.0
    # @raise Beaneater::NotConnected If a connection is unable to be re-established
    def retryable(options = {}, &block)
      options = {:max_retries => 4, :on_retry => nil, :retry_delay => 1.0}.merge!(options)
      retry_count = options[:max_retries]

      begin
        yield

      rescue Beaneater::NotConnected
        if retry_count > 0
          reconnect!
          retry_count -= 1
          options[:on_retry].call if options[:on_retry].respond_to?(:call)
          retry
        else # stop retrying
          raise e
        end
      end
    end

    def tubes
      ensure_connected!
      @beanstalk.tubes
    end

    def stats
      ensure_connected!
      @beanstalk.stats
    end

    def connection
      @beanstalk.connection
    end

    protected

    # Attempt to ensure we're connected to Beanstalk if the missing method is
    # present in the delegate and we haven't shut down the connection on purpose
    # @raise [Beaneater::NotConnected] If beanstalk fails to connect after multiple attempts.
    #def method_missing(m, *args, &block)
      #ensure_connected! if respond_to_missing?(m, false)
      #@beanstalk.send m, *args, &block
    #end

    # Connects to a beanstalk queue
    # @raise Beaneater::NotConnected if the connection cannot be established
    def connect!
      @beanstalk = Beaneater.new(beanstalk_addresses, @options)
      @beanstalk
    end

    # Attempts to ensure a connection to beanstalk is established but only if
    # we're not connected already
    # @param max_retries Integer The maximum number of times to attempt connecting. Defaults to 4
    # @param retry_delay Float   The time to wait between retrying to connect. Defaults to 1.0
    # @raise [Beaneater::NotConnected] If beanstalk fails to connect after multiple attempts.
    # @return Connection This Connection is returned if the connection to beanstalk is open or was able to be reconnected
    def ensure_connected!(max_retries = 4, retry_delay = 1.0)
      return self if connected?

      begin
        reconnect!
        return self

      rescue Beaneater::NotConnected => e
        if max_retries > 0
          max_retries -= 1
          retry
        else # stop retrying
          raise e
        end
      end
    end

    # Returns the beanstalk queue addresses
    #
    # @example
    #   beanstalk_addresses => ["127.0.0.1:11300"]
    #
    def beanstalk_addresses
      uri = self.url.is_a?(Array) ? self.url.first : self.url
      beanstalk_host_and_port(uri)
    end

    # Returns a host and port based on the uri_string given
    #
    # @example
    #   beanstalk_host_and_port("beanstalk://127.0.0.1") => "127.0.0.1:11300"
    #
    def beanstalk_host_and_port(uri_string)
      uri = URI.parse(uri_string)
      raise(BadURL, uri_string) if uri.scheme != 'beanstalk'.freeze
      "#{uri.host}:#{uri.port || 11300}"
    end
  end # Connection
end # Backburner
