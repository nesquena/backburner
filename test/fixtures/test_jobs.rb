$worker_test_count = 0
$worker_success = false

class TestPlainJob
  def self.queue; "test-plain"; end
  def self.perform(x, y); $worker_test_count += x + y + 1; end
end

class TestJob
  include Backburner::Queue
  queue_priority :medium
  queue_respond_timeout 300
  def self.perform(x, y); $worker_test_count += x + y; end
end

class TestSlowJob
  include Backburner::Queue
  queue_priority :medium
  queue_respond_timeout 300
  def self.perform(x, y); sleep 1; $worker_test_count += x + y; end
end

class TestStuckJob
  include Backburner::Queue
  queue_priority :medium
  queue_respond_timeout 300
  def self.perform(_x, _y)
    loop do
      sleep 0.5
    end
  end
end

class TestFailJob
  include Backburner::Queue
  def self.perform(x, y); raise RuntimeError; end
end

class TestRetryJob
  include Backburner::Queue
  def self.perform(x, y)
    $worker_test_count += 1
    raise RuntimeError unless $worker_test_count > 2
    $worker_success = true
  end
end

class TestConfigurableRetryJob
  include Backburner::Queue
  def self.perform(retry_count)
    $worker_test_count += 1
    raise RuntimeError unless $worker_test_count > retry_count
    $worker_success = true
  end
end

class TestAsyncJob
  include Backburner::Performable
  def self.foo(x, y); $worker_test_count = x * y; end
end

class TestLambdaQueueJob
  include Backburner::Queue
  queue lambda { |klass| klass.calculated_queue_name }
  def self.calculated_queue_name; 'lambda-queue' end
end
