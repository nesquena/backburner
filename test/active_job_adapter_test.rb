require File.expand_path('../test_helper', __FILE__)
require 'open3'
require 'rbconfig'

describe "Backburner as the Active Job adapter" do
  def lib
    File.expand_path('../../lib', __FILE__)
  end

  # Runs the app with load_path ahead of the rest of the load path, the first directory first
  def assert_app_works(name, order, load_path)
    namespace = "demo.test.active_job.#{Process.pid}.#{name}"
    app = File.expand_path('../fixtures/active_job_app.rb', __FILE__)
    out, status = Open3.capture2e(RbConfig.ruby, '-w', *load_path.flat_map { |dir| ['-I', dir] }, app, namespace, order)
    assert status.success?, out
    result = JSON.parse(out.lines.last)

    tube = "#{namespace}.adapter"
    assert_equal({ 'tube' => tube, 'pri' => 7, 'ttr' => 120, 'state' => 'ready', 'delay' => 0 }, result['jobs']['now'])
    assert_equal({ 'tube' => tube, 'pri' => 3, 'ttr' => 120, 'state' => 'ready', 'delay' => 0 }, result['jobs']['urgent'])
    # wait: 3 reaches the adapter a little under 3 seconds ahead: rounded up, so it doesn't run early
    assert_equal({ 'tube' => tube, 'pri' => 7, 'ttr' => 120, 'state' => 'delayed', 'delay' => 3 }, result['jobs']['later'])
    # the TTR of a job class with a queue_respond_timeout
    assert_equal({ 'tube' => tube, 'pri' => 7, 'ttr' => 3600, 'state' => 'ready', 'delay' => 0 }, result['jobs']['long'])
    assert_equal({ 'tube' => tube, 'pri' => 7, 'ttr' => 3600, 'state' => 'delayed', 'delay' => 3 }, result['jobs']['long later'])
    assert_equal ['later', 'long', 'long later', 'now', 'urgent'], result['performed']
    # only backburner's own files: RubyGems can warn about its own
    refute_match(/circular require considered harmful - #{Regexp.escape(lib)}\//, out)
  end

  %w(active_job_first backburner_first active_job_only).each do |order|
    it "enqueues and works jobs when the app requires #{order.tr('_', ' ')}" do
      assert_app_works(order, order, [lib])
    end
  end

  # Without Bundler, the lib of the gem activated first comes first on the load path: Active Job's, with its own
  # adapter file of the same name, when the app requires it before backburner
  it "uses this gem's adapter when Active Job's lib comes first on the load path" do
    active_job = Gem::Specification.find_by_name('activejob')
    skip "Rails before 7.2 keep their own adapter" if active_job.version < Gem::Version.new('7.2')
    assert_app_works('active_job_lib_first', 'active_job_first', active_job.full_require_paths + [lib])
  end
end
