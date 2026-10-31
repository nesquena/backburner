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

class TestParentQueueJob
  include Backburner::Queue
  queue "test-parent"
  queue_priority :high
  queue_respond_timeout 250
  def self.perform(x, y); $worker_test_count += x + y; end
end

class TestChildQueueJob < TestParentQueueJob; end

class TestNamedQueueJob
  include Backburner::Queue
  queue lambda { |klass| klass.name.downcase }
  def self.perform; end
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

class TestRetryWithQueueOverridesJob
  include Backburner::Queue
  def self.perform(retry_count)
    $worker_test_count += 1
    raise RuntimeError unless $worker_test_count > retry_count
    $worker_success = true
  end

  def self.queue_max_job_retries
    3
  end

  def self.queue_retry_delay
    0
  end

  def self.queue_retry_delay_proc
    lambda { |min_retry_delay, num_retries| min_retry_delay + (num_retries ** 2) }
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

class TestOverTTRJob
  include Backburner::Queue
  queue_respond_timeout 2
  # Outlives its TTR without Timeout being able to interrupt it (like a blocking C call)
  def self.perform; Thread.handle_interrupt(Object => :never) { sleep 3 }; end
end

# Like an autoloader that doesn't find a file for the constant
module AutoloadingDemo
  def self.const_missing(name); raise LoadError, "cannot load such file -- autoloading_demo/#{name}"; end
end

# Job classes an app autoloads: whose files fail to load, and one whose file isn't there
autoload :TestBrokenNameJob, File.expand_path('../autoload/test_broken_name_job', __FILE__)
autoload :TestBrokenRequireJob, File.expand_path('../autoload/test_broken_require_job', __FILE__)
autoload :TestBrokenNoMethodJob, File.expand_path('../autoload/test_broken_no_method_job', __FILE__)
autoload :TestNoFileJob, File.expand_path('../autoload/test_no_such_job', __FILE__)
