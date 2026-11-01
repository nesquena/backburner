require File.expand_path('../test_helper', __FILE__)
require 'open3'
require 'rbconfig'

describe "Backburner jobs in a Rails app" do
  it "works each job in the app's reloader, once, including an Active Job job, reporting its failures" do
    namespace = "demo.test.rails_reloader.#{Process.pid}" # the underscore keeps its tubes out of the workers given no tubes
    app = File.expand_path('../fixtures/rails_reloader_app.rb', __FILE__)
    out, status = Open3.capture2e(RbConfig.ruby, '-I', File.expand_path('../../lib', __FILE__), app, namespace)
    assert status.success?, out
    result = JSON.parse(out.lines.last)

    # each job ran inside the reloader and started with fresh CurrentAttributes, after a job that failed too
    assert_equal [['set', true], [nil, true], [nil, true]], result['ran']
    # one execution per job (six, the last one exiting): Active Job's own wrap, inside the worker's, didn't start another
    assert_equal 6, result['executions']
    refute result['active_after']
    # a job that exits stops the worker without a report
    assert result['exited']
    # a RetryJob is retried and not reported; a failing job, plain or Active Job, is reported once, with a
    # backburner source where the reloader takes one (Active Support 7.1+); before 7.0 nothing is reported
    assert_equal [1], result['retried']
    active_support = Gem::Version.new(result['active_support'])
    source = active_support >= Gem::Version.new('7.1') ? 'job.backburner' : nil
    expected = active_support >= Gem::Version.new('7.0') ? [['RuntimeError', source]] * 2 : []
    assert_equal expected, result['reported']
  end
end
