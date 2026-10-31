# An app using Backburner as its Active Job adapter. active_job_adapter_test.rb runs it in a child process,
# so Active Job (and Active Support) stay out of the suite's own process.
# Arguments: the tube namespace, then which of the two the app requires first (or active_job_only).
require 'json'
require 'logger' # Active Support 6.1 and 7.0 need Logger loaded first (with concurrent-ruby 1.3.5+)

namespace, order = ARGV
case order
when 'active_job_first' # a Rails app: rails/all, then Bundler.require
  require 'active_job'
  require 'backburner'
when 'backburner_first'
  require 'backburner'
  require 'active_job'
when 'active_job_only' # gem 'backburner', require: false: the adapter loads it
  require 'active_job'
end

ActiveJob::Base.logger = Logger.new(nil)
ActiveJob::Base.queue_adapter = :backburner
Backburner.configure do |config|
  config.beanstalk_url = "beanstalk://127.0.0.1"
  config.tube_namespace = namespace
  config.logger = Logger.new(nil)
  config.reserve_timeout = 5
end

$performed = []
class AdapterTestJob < ActiveJob::Base
  queue_as :adapter
  queue_with_priority 7
  def perform(name)
    $performed << name
  end
end

enqueued = {
  'now' => AdapterTestJob.perform_later('now'),
  'urgent' => AdapterTestJob.set(priority: 3).perform_later('urgent'),
  'later' => AdapterTestJob.set(wait: 3).perform_later('later')
}
beanstalk = Beaneater.new('127.0.0.1')
jobs = enqueued.map do |name, job|
  stats = job.provider_job_id && beanstalk.jobs.find(job.provider_job_id).stats
  [name, stats && { 'tube' => stats.tube, 'pri' => stats.pri, 'state' => stats.state, 'delay' => stats.delay }]
end.to_h
beanstalk.close

worker = Backburner::Workers::Simple.new(['adapter'])
worker.prepare
enqueued.size.times { worker.work_one_job }

puts JSON.generate('jobs' => jobs, 'performed' => $performed.sort)
