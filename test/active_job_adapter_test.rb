require File.expand_path('test_helper', __dir__)
require File.expand_path('fixtures/active_jobs', __dir__)

describe 'ActiveJob::QueueAdapters::BackburnerAdapter class' do
  before do
    clear_jobs!('default')
  end

  describe 'perform_later' do
    should 'enqueues job with arguments' do
      active_job = TestJob.perform_later('first')

      pop_one_job('default') do |job, body|
        assert_equal 'ActiveJob::QueueAdapters::BackburnerAdapter::JobWrapper', body['class']
        assert_equal 'TestJob', body['args'].first['job_class']
        assert_equal active_job.arguments, body['args'].first['arguments']
        assert_equal active_job.job_id, body['args'].first['job_id']
      end
    end

    should 'enqueues job with priority' do
      active_job = TestJob.set(priority: 10).perform_later('first')

      pop_one_job('default') do |job, body|
        assert_equal active_job.priority, body['args'].first['priority']
      end
    end

    should 'enqueues scheduled job' do
      active_job = TestJob.set(wait: 5.seconds).perform_later('first')

      assert_raises(Timeout::Error) do
        pop_one_job('default')
      end

      sleep 5
      pop_one_job('default') do |job, body|
        assert_equal active_job.job_id, body['args'].first['job_id']
      end
    end
  end
end
