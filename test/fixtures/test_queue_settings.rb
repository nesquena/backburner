class TestJobSettings
  include Backburner::Queue
  queue "job-settings:5:10:6"
  def self.perform; end
end

class TestJobSettingsOverride
  include Backburner::Queue
  queue "job-settings-override:5:10:12"
  queue_jobs_limit 10
  queue_garbage_limit 1000
  queue_retry_limit 2
  def self.perform; end
end