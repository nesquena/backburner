require File.expand_path('../test_helper', __FILE__)
require 'open3'
require 'rbconfig'

describe "Backburner as the Active Job adapter" do
  %w(active_job_first backburner_first active_job_only).each do |order|
    it "enqueues and works jobs when the app requires #{order.tr('_', ' ')}" do
      namespace = "demo.test.active_job.#{Process.pid}.#{order}"
      app = File.expand_path('../fixtures/active_job_app.rb', __FILE__)
      out, status = Open3.capture2e(RbConfig.ruby, '-w', '-I', File.expand_path('../../lib', __FILE__), app, namespace, order)
      assert status.success?, out
      # only backburner's own files: RubyGems can warn about its own
      refute_match(%r{circular require considered harmful - \S*(/backburner\.rb|/backburner_adapter\.rb|/lib/backburner/\S+\.rb)$}, out)
      result = JSON.parse(out.lines.last)

      tube = "#{namespace}.adapter"
      assert_equal({ 'tube' => tube, 'pri' => 7, 'state' => 'ready', 'delay' => 0 }, result['jobs']['now'])
      assert_equal({ 'tube' => tube, 'pri' => 3, 'state' => 'ready', 'delay' => 0 }, result['jobs']['urgent'])
      # wait: 3 reaches the adapter a little under 3 seconds ahead: rounded up, so it doesn't run early
      assert_equal({ 'tube' => tube, 'pri' => 7, 'state' => 'delayed', 'delay' => 3 }, result['jobs']['later'])
      assert_equal %w(later now urgent), result['performed']
    end
  end
end
