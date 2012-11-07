require File.expand_path('../test_helper', __FILE__)
require File.expand_path('../fixtures/hooked', __FILE__)

describe "Backburner::Hooks module" do
  before do
    $hooked_fail_count = 0
  end

  describe "for invoke_hook_events method" do
    describe "with before_enqueue" do
      it "should support successful invocation" do
        out = silenced { @res = HookedObjectSuccess.invoke_hook_events(:before_enqueue, 5, 6) }
        assert_equal [nil, nil], @res
        assert_match /!!before_enqueue_foo!! \[5\, 6\]/, out
        assert_match /!!before_enqueue_bar!! \[5\, 6\]/, out
      end

      it "should support fail case" do
        out = silenced { @res = HookedObjectBeforeEnqueueFail.invoke_hook_events(:before_enqueue, 5, 6) }
        assert_equal false, @res
        assert_match /!!before_enqueue_foo!! \[5\, 6\]/, out
      end
    end # before_enqueue

    describe "with after_enqueue" do
      it "should support successful invocation" do
        out = silenced { HookedObjectSuccess.invoke_hook_events(:after_enqueue, 7, 8) }
        assert_match /!!after_enqueue_foo!! \[7\, 8\]/, out
        assert_match /!!after_enqueue_bar!! \[7\, 8\]/, out
      end

      it "should support fail case" do
        assert_raises(HookFailError) do
          silenced { @res = HookedObjectAfterEnqueueFail.invoke_hook_events(:after_enqueue, 5, 6) }
        end
      end
    end # after_enqueue

    describe "with before_perform" do
      it "should support successful invocation" do
        out = silenced { HookedObjectSuccess.invoke_hook_events(:before_perform, 1, 2) }
        assert_match /!!before_perform_foo!! \[1\, 2\]/, out
      end

      it "should support fail case" do
        out = silenced { @res = HookedObjectBeforePerformFail.invoke_hook_events(:before_perform, 5, 6) }
        assert_equal false, @res
        assert_match /!!before_perform_foo!! \[5\, 6\]/, out
      end
    end # before_perform

    describe "with after_perform" do
      it "should support successful invocation" do
        out = silenced { HookedObjectSuccess.invoke_hook_events(:after_perform, 3, 4) }
        assert_match /!!after_perform_foo!! \[3\, 4\]/, out
      end

      it "should support fail case" do
        assert_raises(HookFailError) do
          silenced { @res = HookedObjectAfterPerformFail.invoke_hook_events(:after_perform, 5, 6) }
        end
      end
    end # after_perform

    describe "with on_failure" do
      it "should support successful invocation" do
        out = silenced { HookedObjectSuccess.invoke_hook_events(:on_failure, RuntimeError, 10) }
        assert_match /!!on_failure_foo!! RuntimeError \[10\]/, out
      end
    end # on_failure
  end # invoke_hook_events

  describe "for around_hook_events method" do
    describe "with around_perform" do
      it "should support successful invocation" do
        out = silenced do
          HookedObjectSuccess.around_hook_events(:around_perform, 7, 8) {
            puts "!!FIRED!!"
          }
        end
        assert_match /BEGIN.*?bar.*BEGIN.*cat.*FIRED.*END.*cat.*END.*bar/m, out
        assert_match /!!BEGIN around_perform_bar!! \[7\, 8\]/, out
        assert_match /!!BEGIN around_perform_cat!! \[7\, 8\]/, out
        assert_match /!!FIRED!!/, out
        assert_match /!!END around_perform_cat!! \[7\, 8\]/, out
        assert_match /!!END around_perform_bar!! \[7\, 8\]/, out
      end
    end # successful
  end # around_hook_events
end # Hooks