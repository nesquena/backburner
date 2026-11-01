# Backburner jobs in a Rails app, without Rails itself: Rails.application stands in for an app, with a real
# Active Support executor and reloader set up as railties sets them up (CurrentAttributes reset as an execution
# starts and ends, Active Job's execute wrapped in the reloader). rails_reloader_test.rb runs it in a child
# process, so Active Job (and Active Support) stay out of the suite's own process. Argument: the tube namespace.
require 'json'
require 'logger' # Active Support 6.1 and 7.0 need Logger loaded first (with concurrent-ruby 1.3.5+)
require 'active_support'
require 'active_support/current_attributes'
require 'active_support/reloader'
require 'active_job'
require 'backburner'

app = Struct.new(:executor, :reloader).new(Class.new(ActiveSupport::Executor), Class.new(ActiveSupport::Reloader))
app.reloader.executor = app.executor
app.executor.to_run { Current.reset } # railties resets every CurrentAttributes class, by an API that varies with the version
app.executor.to_complete { Current.reset }
ActiveSupport.on_load(:active_job) do
  ActiveJob::Callbacks.singleton_class.set_callback(:execute, :around, prepend: true) do |_, inner|
    app.reloader.wrap { inner.call }
  end
end
module Rails; end
Rails.define_singleton_method(:application) { app }

$executions = 0
app.executor.to_run { $executions += 1 }
$ran = []
$retried = []

# What the executor reports to Rails.error (Active Support 7.0+), which is the app executor's error reporter
$reported = []
if defined?(ActiveSupport::ErrorReporter)
  ActiveSupport.error_reporter ||= ActiveSupport::ErrorReporter.new if ActiveSupport.respond_to?(:error_reporter=)
  app.executor.error_reporter.subscribe(Class.new do
    def report(error, **options)
      $reported << [error.class.name, options[:source]]
    end
  end.new)
end

ActiveJob::Base.logger = Logger.new(nil)
ActiveJob::Base.queue_adapter = :backburner
Backburner.configure do |config|
  config.beanstalk_url = "beanstalk://127.0.0.1"
  config.tube_namespace = ARGV[0]
  config.logger = Logger.new(nil)
  config.reserve_timeout = 5
end

class Current < ActiveSupport::CurrentAttributes
  attribute :tenant
end

class SetTenantJob
  include Backburner::Queue
  queue "reloader"
  def self.perform(tenant)
    Current.tenant = tenant
    $ran << ['set', !!Rails.application.executor.active?]
  end
end

class ReadTenantJob
  include Backburner::Queue
  queue "reloader"
  def self.perform
    $ran << [Current.tenant, !!Rails.application.executor.active?]
    Current.tenant = "leaked"
    raise "failed" # the wrap ends on an error too
  end
end

class ReadTenantActiveJob < ActiveJob::Base
  queue_as :reloader
  def perform
    $ran << [Current.tenant, !!Rails.application.executor.active?]
  end
end

class RetryingJob
  include Backburner::Queue
  queue "reloader"
  queue_max_job_retries 1
  def self.perform
    raise Backburner::Job::RetryJob # retry without an error
  end
  def self.on_retry_record(count, _delay)
    $retried << count
  end
end

class FailingActiveJob < ActiveJob::Base
  queue_as :reloader
  def perform
    raise "failed"
  end
end

class ExitingJob
  include Backburner::Queue
  queue "reloader"
  def self.perform
    exit # as the worker's TERM and INT handling does
  end
end

Backburner.enqueue SetTenantJob, "acme"
Backburner.enqueue ReadTenantJob
ReadTenantActiveJob.perform_later
Backburner.enqueue RetryingJob
FailingActiveJob.perform_later

worker = Backburner::Workers::Simple.new(['reloader'])
worker.prepare
5.times { worker.work_one_job }
Backburner.enqueue ExitingJob
exited = begin
  worker.work_one_job
  false
rescue SystemExit
  true
end

puts JSON.generate('ran' => $ran, 'executions' => $executions, 'active_after' => !!app.executor.active?,
  'retried' => $retried, 'reported' => $reported, 'exited' => exited, 'active_support' => ActiveSupport::VERSION::STRING)
