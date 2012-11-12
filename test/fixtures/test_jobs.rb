$worker_test_count = 0
$worker_success = false

class TestJob
  include Backburner::Queue
  queue_priority 1000
  def self.perform(x, y); $worker_test_count += x + y; end
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

class TestAsyncJob
  include Backburner::Performable
  def self.foo(x, y); $worker_test_count = x * y; end
end

class ResponseJob
  include Backburner::Queue
  queue_priority 1000
  def self.perform(data)
    $worker_test_count += data['worker_test_count'].to_i if data['worker_test_count']
    $worker_success = true if data['worker_success']
    $worker_test_count = data['worker_test_count_set'].to_i if data['worker_test_count_set']
    $worker_raise = true if data['worker_raise']
  end
end

class TestJobFork
  include Backburner::Queue
  queue_priority 1000
  def self.perform(x, y)
    Backburner::Workers::ThreadsOnFork.enqueue ResponseJob, [{
        :worker_test_count_set => x + y
    }], :queue => 'response'
  end
end

class TestFailJobFork
  include Backburner::Queue
  def self.perform(x, y)
    Backburner::Workers::ThreadsOnFork.enqueue ResponseJob, [{
       :worker_raise => true
    }], :queue => 'response'
  end
end

class TestRetryJobFork
  include Backburner::Queue
  def self.perform(x, y)
    $worker_test_count += 1
    Backburner::Workers::ThreadsOnFork.enqueue ResponseJob, [{
        :worker_test_count => 1
    }], :queue => 'response'

    raise RuntimeError unless $worker_test_count > 2
    Backburner::Workers::ThreadsOnFork.enqueue ResponseJob, [{
        :worker_success => true
    }], :queue => 'response'
  end
end

class TestAsyncJobFork
  include Backburner::Performable
  def self.foo(x, y)
    Backburner::Workers::ThreadsOnFork.enqueue ResponseJob, [{
        :worker_test_count_set => x * y
    }], :queue => 'response'
  end
end