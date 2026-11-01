module Backburner
  # The connections Worker.enqueue puts jobs with, shared by the process's threads and fibers,
  # so enqueueing doesn't open a TCP connection per job (that ran out of ports, #125).
  # A connection is checked out for one enqueue and checked back in after it; up to
  # MAX_IDLE_CONNECTIONS stay open between enqueues and the rest are closed.
  #
  # ceiling: idle connections are only closed when they are next checked out (or when the URL
  # changes or the process exits); a reaper thread would close them sooner.
  class EnqueuePool
    MAX_IDLE_CONNECTIONS = 5

    @current = nil

    # The pool of this process: a forked child gets a new one and leaves its parent's
    # sockets (and a lock another thread may have held at the fork) alone.
    # ceiling: no lock, so threads that race on the first enqueue (or the first after a fork) may
    # each make a pool; only the last one is kept, and the others' connections stay open until
    # garbage collected. A class-level lock would need replacing after a fork, as a thread that
    # doesn't exist in the child may hold it.
    def self.current
      pool = @current
      pool && pool.pid == Process.pid ? pool : (@current = new)
    end

    attr_reader :pid

    def initialize
      @pid  = Process.pid
      @lock = Mutex.new
      @url  = nil
      @idle = [] # [connection, idle since], most recently used last
    end

    # Yields a connection to the configured beanstalk_url. If the block doesn't finish (it raises,
    # or its thread is killed, or it is left with throw), the connection is closed instead of
    # checked back in, since an interrupted command may have left a reply unread on it.
    def with_connection
      url, connection = checkout
      finished = false
      begin
        result = yield connection
        finished = true
        result
      ensure
        if finished
          checkin(url, connection)
        else
          connection.close rescue nil
        end
      end
    end

    private

    def checkout
      url = Backburner.configuration.beanstalk_url
      max_idle = Backburner.configuration.enqueue_connection_max_idle
      to_close = []
      connection = @lock.synchronize do
        unless @url == url # the URL changed: its old connections go
          to_close.concat(@idle)
          @idle = []
          @url = url
        end
        # Connections idle for too long may have been dropped by a firewall or load balancer
        # without either end knowing, and a put on one would hang until TCP gives up
        now = monotonic_now
        expired, @idle = @idle.partition { |_conn, since| max_idle && now - since > max_idle }
        to_close.concat(expired)
        conn, _since = @idle.pop
        conn
      end
      to_close.each { |conn, _since| conn.close rescue nil }
      [url, connection || Backburner::Connection.new(url)]
    end

    def checkin(url, connection)
      kept = @lock.synchronize do
        if @url == url && @idle.size < MAX_IDLE_CONNECTIONS
          @idle.push([connection, monotonic_now])
        end
      end
      connection.close rescue nil unless kept
    end

    def monotonic_now
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
  end # EnqueuePool
end # Backburner
