require File.expand_path('../test_helper', __FILE__)
require 'open3'
require 'rbconfig'

describe "Backburner jobs in a Rails app" do
  it "works each job in the app's reloader, once, including an Active Job job" do
    namespace = "demo.test.rails_reloader.#{Process.pid}" # the underscore keeps its tubes out of the workers given no tubes
    app = File.expand_path('../fixtures/rails_reloader_app.rb', __FILE__)
    out, status = Open3.capture2e(RbConfig.ruby, '-I', File.expand_path('../../lib', __FILE__), app, namespace)
    assert status.success?, out
    result = JSON.parse(out.lines.last)

    # each job ran inside the reloader and started with fresh CurrentAttributes, after a job that failed too
    assert_equal [['set', true], [nil, true], [nil, true]], result['ran']
    # one execution per job: Active Job's own wrap, inside the worker's, didn't start another
    assert_equal 3, result['executions']
    refute result['active_after']
  end
end
