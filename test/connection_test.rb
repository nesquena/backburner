require File.expand_path('../test_helper', __FILE__)

describe "Backburner::Connection class" do
  describe "for initialize with single url" do
    before do
      @connection = Backburner::Connection.new("beanstalk://localhost")
    end

    it "should store url in accessor" do
      assert_equal "beanstalk://localhost", @connection.url
    end

    it "should setup beanstalk connection" do
      assert_kind_of Beaneater::Pool, @connection.beanstalk
    end
  end # initialize single connection

  describe "for initialize with multiple urls" do
    it "should support single string with commas" do
      @connection = Backburner::Connection.new("beanstalk://localhost,beanstalk://localhost")
      connections = @connection.beanstalk.connections
      assert_equal 2, connections.size
      assert_equal ['localhost:11300','localhost:11300'], connections.map(&:address)
    end

    it "should support array of connections" do
      @connection = Backburner::Connection.new(['beanstalk://127.0.0.1:11300','beanstalk://localhost'])
      connections = @connection.beanstalk.connections
      assert_equal 2, @connection.beanstalk.connections.size
      assert_equal ['127.0.0.1:11300','localhost:11300'], connections.map(&:address)
    end
  end # initialize

  describe "for bad uri" do
    it "should raise a BadUrl" do
      assert_raises(Backburner::Connection::BadURL) {
        @connection = Backburner::Connection.new("fake://foo")
      }
    end
  end

  describe "for delegated methods" do
    before do
      @connection = Backburner::Connection.new("beanstalk://localhost")
    end

    it "delegate methods to beanstalk connection" do
      assert_equal "localhost", @connection.connections.first.host
    end
  end # delegator
end # Connection

describe "Backburner::IronMQConnection class" do

  it "should authenticate to the IronMQ server" do
    transmitted_msgs = []
    msg_handler = Proc.new{|outbound_str| transmitted_msgs << outbound_str }
    replace_method(Beaneater::Pool, :transmit_to_all, msg_handler) do
      auth = {:project_id => 'unknown_project_id', :token => 'unknown_token'}
      @connection = Backburner::IronMQConnection.new("beanstalk://localhost", :auth => auth)
    end
    assert_equal transmitted_msgs[0], "put 0 0 0 38\r\n"
    assert_equal transmitted_msgs[1], "oauth unknown_token unknown_project_id"
  end

end