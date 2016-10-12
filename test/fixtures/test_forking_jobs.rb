class ResponseForkingJob
  include Backburner::Queue
  queue_priority 1000
  def self.perform(data)
    $worker_test_count += data['worker_test_count'].to_i if data['worker_test_count']
    $worker_success = data['worker_success'] if data['worker_success']
    $worker_test_count = data['worker_test_count_set'].to_i if data['worker_test_count_set']
    $worker_raise = data['worker_raise'] if data['worker_raise']
  end
end

class TestJobForking
  include Backburner::Queue
  queue_priority 1000
  def self.perform(x, y)
    Backburner::Workers::Forking.enqueue ResponseForkingJob, [{
        :worker_test_count_set => x + y
    }], :queue => 'response'
  end
end

class TestFailJobForking
  include Backburner::Queue
  def self.perform(x, y)
    Backburner::Workers::Forking.enqueue ResponseForkingJob, [{
       :worker_raise => true
    }], :queue => 'response'
  end
end

class TestRetryJobForking
  include Backburner::Queue
  def self.perform(x, y)
    if $worker_test_count <= 2
      Backburner::Workers::Forking.enqueue ResponseForkingJob, [{
          :worker_test_count => 1
      }], :queue => 'response'

      raise RuntimeError
    else # succeeds
      Backburner::Workers::Forking.enqueue ResponseForkingJob, [{
          :worker_test_count => 1,
          :worker_success => true
      }], :queue => 'response'
    end
  end
end

class TestAsyncJobForking
  include Backburner::Performable
  def self.foo(x, y)
    Backburner::Workers::Forking.enqueue ResponseForkingJob, [{
        :worker_test_count_set => x * y
    }], :queue => 'response'
  end
end