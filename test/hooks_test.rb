require File.expand_path('../test_helper', __FILE__)
require File.expand_path('../fixtures/hooked', __FILE__)

describe "Backburner::Hooks module" do
  before do
    $hooked_fail_count = 0
    @hooks = Backburner::Hooks
  end

  describe "for invoke_hook_events method" do
    describe "with before_enqueue" do
      it "should support successful invocation" do
        out = silenced { @res = @hooks.invoke_hook_events(HookedObjectSuccess, :before_enqueue, 5, 6) }
        assert_equal [nil, nil], @res
        assert_match(/!!before_enqueue_foo!! \[5\, 6\]/, out)
        assert_match(/!!before_enqueue_bar!! \[5\, 6\]/, out)
      end

      it "should support fail case" do
        out = silenced { @res = @hooks.invoke_hook_events(HookedObjectBeforeEnqueueFail, :before_enqueue, 5, 6) }
        assert_equal false, @res
        assert_match(/!!before_enqueue_foo!! \[5\, 6\]/, out)
      end
    end # before_enqueue

    describe "with after_enqueue" do
      it "should support successful invocation" do
        out = silenced { @hooks.invoke_hook_events(HookedObjectSuccess, :after_enqueue, 7, 8) }
        assert_match(/!!after_enqueue_foo!! \[7\, 8\]/, out)
        assert_match(/!!after_enqueue_bar!! \[7\, 8\]/, out)
      end

      it "should support fail case" do
        assert_raises(HookFailError) do
          silenced { @res = @hooks.invoke_hook_events(HookedObjectAfterEnqueueFail, :after_enqueue, 5, 6) }
        end
      end
    end # after_enqueue

    describe "with before_perform" do
      it "should support successful invocation" do
        out = silenced { @hooks.invoke_hook_events(HookedObjectSuccess, :before_perform, 1, 2) }
        assert_match(/!!before_perform_foo!! \[1\, 2\]/, out)
      end

      it "should support fail case" do
        out = silenced { @res = @hooks.invoke_hook_events(HookedObjectBeforePerformFail, :before_perform, 5, 6) }
        assert_equal false, @res
        assert_match(/!!before_perform_foo!! \[5\, 6\]/, out)
      end
    end # before_perform

    describe "with after_perform" do
      it "should support successful invocation" do
        out = silenced { @hooks.invoke_hook_events(HookedObjectSuccess, :after_perform, 3, 4) }
        assert_match(/!!after_perform_foo!! \[3\, 4\]/, out)
      end

      it "should support fail case" do
        assert_raises(HookFailError) do
          silenced { @res = @hooks.invoke_hook_events(HookedObjectAfterPerformFail, :after_perform, 5, 6) }
        end
      end
    end # after_perform

    describe "with on_failure" do
      it "should support successful invocation" do
        out = silenced { @hooks.invoke_hook_events(HookedObjectSuccess, :on_failure, RuntimeError, 10) }
        assert_match(/!!on_failure_foo!! RuntimeError \[10\]/, out)
      end
    end # on_failure

    describe 'with on_retry' do
      it "should support successful invocation" do
        out = silenced { @hooks.invoke_hook_events(HookedObjectSuccess, :on_retry, 1, 0, 10) }
        assert_match(/!!on_retry_foo!! 1 0 \[10\]/, out)
      end
    end

    describe 'with on_bury' do
      it "should support successful invocation" do
        out = silenced { @hooks.invoke_hook_events(HookedObjectSuccess, :on_bury, 10) }
        assert_match(/!!on_bury_foo!! \[10\]/, out)
      end
    end

    describe "with on_reconnect" do
      it "should support successful invocation" do
        out = silenced { @hooks.invoke_hook_events(HookedWorker.new, :on_reconnect)}
        assert_match(/!!on_reconnect!!/, out)
      end
    end
  end # invoke_hook_events

  describe "for around_hook_events method" do
    describe "with around_perform" do
      it "should support successful invocation" do
        out = silenced do
          @hooks.around_hook_events(HookedObjectSuccess, :around_perform, 7, 8) {
            puts "!!FIRED!!"
          }
        end
        assert_match(/BEGIN.*?bar.*BEGIN.*cat.*FIRED.*END.*cat.*END.*bar/m, out)
        assert_match(/!!BEGIN around_perform_bar!! \[7\, 8\]/, out)
        assert_match(/!!BEGIN around_perform_cat!! \[7\, 8\]/, out)
        assert_match(/!!FIRED!!/, out)
        assert_match(/!!END around_perform_cat!! \[7\, 8\]/, out)
        assert_match(/!!END around_perform_bar!! \[7\, 8\]/, out)
      end
    end # successful
  end # around_hook_events

  describe "finding a class's hooks" do
    # The hooks invoke_hook_events calls, by the names they return
    def hooks_called(hookable, event)
      @hooks.invoke_hook_events(hookable, event)
    end

    def hook_class(parent = Object, &block)
      Class.new(parent) do
        def self.hook(*names) names.each { |name| define_singleton_method(name) { name } } end
        class_eval(&block) if block
      end
    end

    it "calls the class's own hooks, its superclasses' and those of the modules they extend, by name" do
      mod = Module.new { def before_perform_mod; :before_perform_mod end }
      parent = hook_class { hook :before_perform_parent, :after_perform_parent; extend mod }
      job = hook_class(parent) { hook :before_perform_b, :before_perform_a }
      assert_equal [:before_perform_a, :before_perform_b, :before_perform_mod, :before_perform_parent], hooks_called(job, :before_perform)
      assert_equal [:after_perform_parent], hooks_called(job, :after_perform)
    end

    it "finds hooks defined after its first lookup" do
      mod = Module.new
      job = hook_class { hook :before_perform_a }
      assert_equal [:before_perform_a], hooks_called(job, :before_perform)
      job.hook :before_perform_later
      job.extend mod
      mod.send(:define_method, :before_perform_module) { :before_perform_module }
      assert_equal [:before_perform_a, :before_perform_later, :before_perform_module], hooks_called(job, :before_perform)
    end

    it "calls protected hooks but not private, undefined or removed ones" do
      parent = hook_class { hook :before_perform_private, :before_perform_undefined, :before_perform_removed, :before_perform_kept }
      job = hook_class(parent) { hook :before_perform_protected, :before_perform_removed }
      job.singleton_class.send(:protected, :before_perform_protected)
      job.singleton_class.send(:private, :before_perform_private)
      job.singleton_class.send(:undef_method, :before_perform_undefined)
      job.singleton_class.send(:remove_method, :before_perform_removed)
      parent.singleton_class.send(:remove_method, :before_perform_removed)
      assert_equal [:before_perform_kept, :before_perform_protected], hooks_called(job, :before_perform)
      assert_equal [:before_perform_kept, :before_perform_private, :before_perform_undefined], hooks_called(parent, :before_perform)
    end

    it "leaves out a hook a module prepended to the class makes private" do
      job = hook_class { hook :before_perform_a, :before_perform_b }
      job.singleton_class.prepend(Module.new { private; def before_perform_b; end })
      assert_equal [:before_perform_a], hooks_called(job, :before_perform)
    end

    it "leaves out a hook every object has" do
      Kernel.send(:define_method, :before_perform_everywhere) { :everywhere }
      job = hook_class { hook :before_perform_everywhere, :before_perform_a }
      assert_equal [:before_perform_a], hooks_called(job, :before_perform)
    ensure
      Kernel.send(:remove_method, :before_perform_everywhere)
    end

    it "calls the hooks a class that defines its own methods lists" do
      job = hook_class do
        hook :before_perform_a, :before_perform_hidden
        def self.methods(*) super - [:before_perform_hidden] end
      end
      assert_equal [:before_perform_a], hooks_called(job, :before_perform)
    end

    it "calls the hooks of a module, an object or a class that isn't an Object" do
      # more modules than Object's singleton class has, so that their number alone doesn't tell them apart
      count = Object.singleton_class.ancestors.size + 2
      extensions = (1..count).map { |i| Module.new { define_method(:"before_perform_ext#{i}") { :"before_perform_ext#{i}" } } }
      mod = Module.new { def self.before_perform_mod; :before_perform_mod end }
      object = Object.new
      def object.before_perform_object; :before_perform_object end
      basic = Class.new(BasicObject) { def self.before_perform_basic; :before_perform_basic end }
      [mod, object, basic].each { |hookable| extensions.each { |extension| hookable.extend(extension) } }
      extended = (1..count).map { |i| :"before_perform_ext#{i}" }
      assert_equal (extended + [:before_perform_mod]).sort, hooks_called(mod, :before_perform)
      assert_equal (extended + [:before_perform_object]).sort, hooks_called(object, :before_perform)
      assert_equal ([:before_perform_basic] + extended).sort, hooks_called(basic, :before_perform)
    end

    it "calls a hook once when a class and its superclass both define it" do
      parent = hook_class { hook :before_perform_a }
      job = hook_class(parent) { hook :before_perform_a }
      assert_equal [:before_perform_a], hooks_called(job, :before_perform)
    end

    it "calls only the hooks whose names start with the event" do
      job = hook_class { hook :before_perform_a, :my_before_perform_b }
      assert_equal [:before_perform_a], hooks_called(job, :before_perform)
    end

    it "uses the class's own singleton class even when the class redefines singleton_class" do
      other = hook_class { hook :before_perform_other }
      job = hook_class { hook :before_perform_a }
      job.define_singleton_method(:singleton_class) { other.singleton_class }
      assert_equal [:before_perform_a], hooks_called(job, :before_perform)
    end

    it "raises as before for a class whose methods is private" do
      job = hook_class { hook :before_perform_a }
      job.singleton_class.send(:private, :methods)
      assert_raises(NoMethodError) { hooks_called(job, :before_perform) }
    end

    it "raises as before for a class whose methods is undefined" do
      job = hook_class { hook :before_perform_a }
      job.singleton_class.send(:undef_method, :methods)
      assert_raises(NoMethodError) { hooks_called(job, :before_perform) }
    end

    it "finds a plain class's hooks without listing its methods" do
      job = hook_class { hook :before_perform_a }
      lookup = ->(hookable) { Backburner::Hooks.send(:class_hook_events, hookable, /^before_perform/) }
      assert_equal [:before_perform_a], lookup.(job)
      assert_nil lookup.(Module.new), "a module takes the general lookup"
      assert_nil lookup.(Object.new), "an object takes the general lookup"
      assert_nil lookup.(Class.new(BasicObject)), "a class that isn't an Object takes the general lookup"
    end

    it "raises as before when Object's methods is private, even for a class that lists its own" do
      job = hook_class { hook :before_perform_a }
      job.singleton_class.prepend(Kernel) # the class lists its methods with Kernel's own public methods again
      Object.singleton_class.send(:private, :methods)
      assert_nil Backburner::Hooks.send(:class_hook_events, job, /^before_perform/)
      assert_raises(NoMethodError) { hooks_called(job, :before_perform) }
    ensure
      Object.singleton_class.send(:remove_method, :methods) # drops the entry `private` added
      assert_equal [:before_perform_a], Backburner::Hooks.send(:class_hook_events, hook_class { hook :before_perform_a }, /^before_perform/)
    end
  end # finding a class's hooks
end # Hooks
