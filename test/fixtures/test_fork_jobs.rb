class ResponseJob
  include Backburner::Queue
  queue_priority 1000
  def self.perform(data)
    $worker_test_count += data['worker_test_count'].to_i if data['worker_test_count']
    $worker_success = data['worker_success'] if data['worker_success']
    $worker_test_count = data['worker_test_count_set'].to_i if data['worker_test_count_set']
    $worker_raise = data['worker_raise'] if data['worker_raise']
  end
end

class TestJobFork
  include Backburner::Queue
  queue "test-job-fork"
  queue_priority 1000
  def self.perform(x, y)
    Backburner::Workers::ThreadsOnFork.enqueue ResponseJob, [{
        :worker_test_count_set => x + y
    }], :queue => 'response'
  end
end

class TestFailJobFork
  include Backburner::Queue
  queue "test-fail-job-fork"
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

    if $worker_test_count <= 2
      Backburner::Workers::ThreadsOnFork.enqueue ResponseJob, [{
          :worker_test_count => 1
      }], :queue => 'response'

      raise RuntimeError
    else # succeeds
      Backburner::Workers::ThreadsOnFork.enqueue ResponseJob, [{
          :worker_test_count => 1,
          :worker_success => true
      }], :queue => 'response'
    end
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