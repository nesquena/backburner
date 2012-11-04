require File.expand_path('../test_helper', __FILE__)

describe "Backburner::Connection class" do
  describe "for initialize" do
    before do
      @connection = Backburner::Connection.new("beanstalk://localhost")
    end

    it "should store url in accessor" do
      assert_equal "beanstalk://localhost", @connection.url
    end

    it "should setup beanstalk connection" do
      assert_kind_of Beaneater::Pool, @connection.beanstalk
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