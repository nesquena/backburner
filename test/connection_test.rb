require File.expand_path('../test_helper', __FILE__)

describe "Echelon::Connection class" do
  describe "for initialize" do
    before do
      @connection = Echelon::Connection.new("beanstalk://localhost")
    end

    it "should store url in accessor" do
      assert_equal "beanstalk://localhost", @connection.url
    end

    it "should setup beanstalk connection" do
      assert_kind_of Beanstalk::Pool, @connection.beanstalk
    end
  end # initialize

  describe "for bad uri" do
    it "should raise a BadUrl" do
      assert_raises(Echelon::Connection::BadURL) {
        @connection = Echelon::Connection.new("fake://foo")
      }
    end
  end

  describe "for delegated methods" do
    before do
      @connection = Echelon::Connection.new("beanstalk://localhost")
    end

    it "delegate methods to beanstalk connection" do
      assert_equal "localhost:11300", @connection.list_tubes.keys.first
    end
  end # delegator
end # Connection