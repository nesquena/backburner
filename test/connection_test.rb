require File.expand_path('../test_helper', __FILE__)

describe "Backburner::Connection class" do
  describe "for initialize with single url" do
    before do
      @connection = Backburner::Connection.new("beanstalk://127.0.0.1")
    end

    it "should store url in accessor" do
      assert_equal "beanstalk://127.0.0.1", @connection.url
    end

    it "should setup beanstalk connection" do
      assert_kind_of Beaneater, @connection.beanstalk
    end
  end # initialize single connection

  describe "for initialize with url" do
    it "should delegate the address url correctly" do
      @connection = Backburner::Connection.new("beanstalk://127.0.0.1")
      connection = @connection.beanstalk.connection
      assert_equal '127.0.0.1:11300', connection.address
    end
  end # initialize

  describe "for bad uri" do
    it "should raise a BadUrl" do
      assert_raises(Backburner::Connection::BadURL) {
        @connection = Backburner::Connection.new("fake://foo")
      }
    end
  end

  describe "for initialize with on_reconnect block" do
    it "should store the block for use upon reconnect" do
      callback = proc {}
      connection = Backburner::Connection.new('beanstalk://127.0.0.1', &callback)
      assert_equal callback, connection.on_reconnect
    end
  end

  describe "dealing with connecting and reconnecting" do
    before do
      @connection = Backburner::Connection.new('beanstalk://127.0.0.1')
    end

    it "should know if its connection is open" do
      assert_equal true, @connection.connected?
      @connection.close
      assert_equal false, @connection.connected?
    end

    it "should be able to attempt reconnecting to beanstalk" do
      @connection.close
      assert_equal false, @connection.connected?
      @connection.reconnect!
      assert_equal true, @connection.connected?
    end

    it "should allow for retryable commands" do
      @result = false
      @connection.close
      @connection.retryable { @result = true }
      assert_equal true, @result
    end

    it "should provide a hook when a retryable command successfully retries" do
      @result = false
      @retried = false
      @connection.close
      callback = proc { @result = true }
      @connection.retryable(:on_retry => callback) do
        unless @retried
          @retried = true
          raise Beaneater::NotConnected.new
        end
      end
      assert_equal true, @result
    end

    it "should provide a hook when the connection successfully reconnects" do
      reconnected = false
      retried = false
      @connection.close
      @connection.on_reconnect = proc { reconnected = true }
      @connection.retryable do
        unless retried
          retried = true
          raise Beaneater::NotConnected.new
        end
      end
      assert_equal true, reconnected
    end

    it "should call the on_reconnect hook before the on_retry hook" do
      @result = []
      @retried = false
      @connection.close
      @connection.on_reconnect = proc { @result << "reconnect" }
      on_retry = proc { @result << "retry" }
      @connection.retryable(:on_retry => on_retry) do
        unless @retried
          @retried = true
          raise Beaneater::NotConnected.new
        end
      end
      assert_equal %w(reconnect retry), @result
    end

    describe "ensuring the connection is open" do
      it "should reattempt the connection to beanstalk several times" do
        stats = @connection.stats
        simulate_disconnect(@connection)
        new_connection = Beaneater.new('127.0.0.1:11300')
        Beaneater.expects(:new).twice.raises(Beaneater::NotConnected).then.returns(new_connection)
        @connection.tubes
        assert_equal true, @connection.connected?
      end

      it "should not attempt reconnecting if the current connection is open" do
        assert_equal true, @connection.connected?
        Beaneater.expects(:new).never
        @connection.tubes
      end

      describe "when reconnecting is successful" do
        it "should allow for a callback" do
          @result = false
          simulate_disconnect(@connection)
          @connection.on_reconnect = proc { @result = true }
          @connection.tubes
          assert_equal true, @result
        end

        it "should pass self to the callback" do
          result = nil
          simulate_disconnect(@connection)
          @connection.on_reconnect = lambda { |conn| result = conn }
          @connection.tubes
          assert_equal result, @connection
        end
      end
    end

    describe "when unable to ensure its connected" do
      it "should raise Beaneater::NotConnected" do
        Beaneater.stubs(:new).raises(Beaneater::NotConnected)
        simulate_disconnect(@connection, 1) # since we're stubbing Beaneater.new above we only to simlulate the disconnect of our current connection
        assert_raises Beaneater::NotConnected do
          @connection.tubes
        end
      end
    end

    describe "when using the retryable method" do
      it "should yield to the block multiple times" do
        expected    = 2
        retry_count = 0
        @connection.retryable(max_retries: expected) do
          if retry_count < 2
            retry_count += 1
            raise Beaneater::NotConnected
          end
        end
        assert_equal expected, retry_count
      end
    end
  end

  describe "for delegated methods" do
    before do
      @connection = Backburner::Connection.new("beanstalk://127.0.0.1")
    end

    it "delegate methods to beanstalk connection" do
      assert_equal "127.0.0.1", @connection.connection.host
    end
  end # delegator
end # Connection
