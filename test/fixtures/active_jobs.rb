require 'active_job'
require 'active_job/queue_adapters/backburner_adapter'

ActiveJob::Base.queue_adapter = :backburner
ActiveJob::Base.logger = nil

class TestJob < ActiveJob::Base
  def perform(arg)
    true
  end
end
