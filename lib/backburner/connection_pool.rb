module Backburner
  class ConnectionPool
    class NoActiveConnection < RuntimeError; end

    attr_accessor :connections
    attr_accessor :failed_connections
    attr_accessor :last_reconnect

    attr_accessor :on_reconnect

    attr_accessor :current_connection

    attr_accessor :success

    RECONNECT_FAILED_TIME = 15
    CONSECUTIVE_SUCCESS_TUBE = 20

    def initialize(beanstalk_urls, options = {}, &on_reconnect)
      @beanstalk_urls = beanstalk_urls.shuffle
      @counter = rand(beanstalk_urls.size * CONSECUTIVE_SUCCESS_TUBE)
      @options = options
      @on_reconnect = on_reconnect
      connect!
    end


    def connect!
      @connections = []
      @failed_connections = []

      errors = []

      @beanstalk_urls.each do |url|
        begin
          conn = Backburner::Connection.new(url, @options, &@on_reconnect)
          @connections << conn
        rescue Exception => e
          errors << e
          @failed_connections << url
        end
      end

      @last_reconnect = Time.now

      raise errors.first if @connections.count < 1

    end

    def reconnect!
      close_all
      connect!
      connections.each do |conn|
        @on_reconnect.call(conn) if @on_reconnect.respond_to?(:call)
      end
    end

    def pick_connection
      inc = @success ? 1 : CONSECUTIVE_SUCCESS_TUBE
      @counter += inc
      @success = false
      reconnect_failed_connections if (@last_reconnect + RECONNECT_FAILED_TIME) < Time.now
      raise NoActiveConnection if connections.size.zero?
      idx = (@counter / CONSECUTIVE_SUCCESS_TUBE) % connections.size
      self.current_connection = connections[idx]
      raise NoActiveConnection if connections.size.zero?
      return self.current_connection
    end

    def reconnect_with_backoff
      @reconnect_backoff ||= 0
      sleep_time = @reconnect_backoff < 10 ? @reconnect_backoff : 10
      sleep sleep_time

      reconnect!
      @reconnect_backoff = 0 if self.alive?
    rescue Beaneater::NotConnected
      @reconnect_backoff += 1
    end

    def deactivate(conn)
      connections.delete conn
      failed_connections << conn.url
    end

    def reconnect_failed_connections
      urls = @failed_connections
      @failed_connections = []
      urls.each do |url|
        begin
          conn = Backburner::Connection.new(url, @options, &@on_reconnect)
          @on_reconnect.call(conn) if @on_reconnect.respond_to? :call
          @connections << conn
        rescue
          @failed_connections << url
        end
      end
      @last_reconnect = Time.now
    end

    def alive?
      connections.any? do |conn|
        conn.connected?
      end
    end

    def close_all
      connections.each do |conn|
        begin; conn.close; rescue; end
      end
    end

  end
end
