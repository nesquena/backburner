require File.expand_path('../test_helper', __FILE__)
require 'open3'
require 'rbconfig'
require 'json'

describe "Backburner as the Active Job adapter, for scheduled jobs" do
  # Runs in a child process, so Active Job (and Active Support) stay out of the suite's own process
  def scheduling_app
    <<-RUBY
    require 'json'
    require 'logger'
    require 'active_job'
    require 'backburner'
    require 'active_job/queue_adapters/backburner_adapter'

    ActiveJob::Base.logger = Logger.new(nil)
    ActiveJob::Base.queue_adapter = :backburner
    Backburner.configure do |config|
      config.beanstalk_url = "beanstalk://127.0.0.1"
      config.tube_namespace = ARGV[0]
      config.logger = Logger.new(nil)
    end

    class ScheduledTestJob < ActiveJob::Base
      queue_as :scheduled
      def perform; end
    end

    jobs = { 'wait 1' => ScheduledTestJob.set(wait: 1), 'wait 0.5' => ScheduledTestJob.set(wait: 0.5) }
    beanstalk = Beaneater.new('127.0.0.1')
    delays = jobs.map do |name, job|
      stats = beanstalk.jobs.find(job.perform_later.provider_job_id).stats
      [name, [stats.delay, stats.state]]
    end.to_h
    beanstalk.close
    puts JSON.generate(delays)
    RUBY
  end

  it "rounds the delay up to whole seconds, so the job never runs early" do
    active_job = Gem.loaded_specs['activejob']
    if active_job && active_job.version < Gem::Version.new('7.2')
      skip "the adapter subclasses Active Job's AbstractAdapter, which Active Job #{active_job.version} lacks"
    end
    namespace = "demo.test.active_job.#{Process.pid}"
    out, status = Open3.capture2e(RbConfig.ruby, '-I', File.expand_path('../../lib', __FILE__), '-e', scheduling_app, namespace)
    assert status.success?, out
    assert_equal({ 'wait 1' => [1, 'delayed'], 'wait 0.5' => [1, 'delayed'] }, JSON.parse(out.lines.last))
  ensure
    conn = beanstalk_connection
    conn.tubes.find("#{namespace}.scheduled").clear if namespace
    conn.close
  end
end
