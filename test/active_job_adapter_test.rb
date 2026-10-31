require File.expand_path('../test_helper', __FILE__)
require 'open3'
require 'rbconfig'

describe "Backburner as the Active Job adapter" do
  %w(active_job_first backburner_first).each do |order|
    it "enqueues and works jobs when the app requires #{order.sub('_first', '')} first" do
      namespace = "demo.test.active_job.#{Process.pid}.#{order}"
      app = File.expand_path('../fixtures/active_job_app.rb', __FILE__)
      out, status = Open3.capture2e(RbConfig.ruby, '-I', File.expand_path('../../lib', __FILE__), app, namespace, order)
      assert status.success?, out
      result = JSON.parse(out.lines.last)

      tube = "#{namespace}.adapter"
      assert_equal({ 'tube' => tube, 'pri' => 7, 'state' => 'ready' }, result['jobs']['now'])
      assert_equal({ 'tube' => tube, 'pri' => 3, 'state' => 'ready' }, result['jobs']['urgent'])
      assert_equal({ 'tube' => tube, 'pri' => 7, 'state' => 'delayed' }, result['jobs']['later'])
      assert_equal %w(later now urgent), result['performed']
    end
  end
end
