module Backburner
  class ConnectionPool
    class NoActiveConnection < RuntimeError; end

    attr_accessor :connections
    attr_accessor :active_connections
    attr_accessor :inactive_connections
    attr_accessor :failed_connections
    attr_accessor :last_reconnect

    attr_accessor :on_reconnect

    attr_accessor :current_connection

    DEACTIVATE_TIME = 60 * 3
    RECONNECT_FAILED_TIME = 60 * 10

    def initialize(beanstalk_urls, options = {}, &on_reconnect)
      @beanstalk_urls = beanstalk_urls
      @counter = rand(beanstalk_urls.size)
      @options = options
      @on_reconnect = on_reconnect
      connect!
    end


    def connect!
      @connections = []
      @active_connections = []
      @inactive_connections = {}
      @failed_connections = []

      errors = []

      @beanstalk_urls.each do |url|
        begin
          conn = Backburner::Connection.new(url, @options)
          @connections << conn
          @active_connections << conn if conn.connected?
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
      @on_reconnect.call(self) if @on_reconnect.respond_to?(:call)
    end

    def pick_connection
      @counter += 1
      reactivate_connections
      reconnect_failed_connections if (@last_reconnect + RECONNECT_FAILED_TIME) < Time.now
      idx = @counter % active_connections.size
      self.current_connection = active_connections[idx]
      raise NoActiveConnection unless self.current_connection
      return self.current_connection
    end

    def deactivate(conn)
      active_connections.delete conn
      inactive_connections[Time.now.to_f] = conn
    end

    def reactivate_connections
      inactive_connections.each do |ts, conn|
        if (ts + DEACTIVATE_TIME) > Time.now.to_f
          active_connections << conn
          inactive_connections.delete ts
        end
      end
    end

    def reconnect_failed_connections
      urls = @failed_connections
      @failed_connections = []
      urls.each do |url|
        begin
          conn = Backburner::Connection.new(url, @options)
          @connections << conn
          @active_connections << conn if conn.connected?
        rescue
          @failed_connections << url
        end
      end
      @last_reconnect = Time.now
    end

    def alive?
      active_connections.any? do |conn|
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
