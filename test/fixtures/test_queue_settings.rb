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
class TestTubeLimitsJob
  include Backburner::Queue
  queue "tube-limits"
  queue_jobs_limit 5
  queue_garbage_limit 100
  queue_retry_limit 3
  def self.perform; end
end

# Shares its parent's tube, whose options stay the parent's
class TestTubeLimitsChildJob < TestTubeLimitsJob
  queue_jobs_limit 1
  queue_garbage_limit 7
end

class TestTubeLimitsLambdaJob
  include Backburner::Queue
  queue lambda { |klass| "tube-limits-#{klass.name.downcase}" }
  queue_jobs_limit 3
  def self.perform; end
end

# Gets a tube of its own from the inherited lambda, so its options are its own
class TestTubeLimitsLambdaChildJob < TestTubeLimitsLambdaJob
  queue_jobs_limit 4
end

class TestTubeFewLimitsJob
  include Backburner::Queue
  queue "tube-few-limits"
  queue_retry_limit 2
  def self.perform; end
end

# Shares its parent's tube and fills in the limits the parent leaves unset
class TestTubeFewLimitsChildJob < TestTubeFewLimitsJob
  queue_jobs_limit 3
  queue_garbage_limit 50
  queue_retry_limit 9
end
