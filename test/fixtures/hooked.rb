$hooked_fail_count = 0
class HookFailError < RuntimeError; end

class HookedObjectBeforeEnqueueFail
  include Backburner::Performable

  def self.before_enqueue_abe(*args)
    puts "!!before_enqueue_foo!! #{args.inspect}"
  end

  def self.before_enqueue_bar(*args)
    return false
  end
end


class HookedObjectAfterEnqueueFail
  def self.after_enqueue_abe(*args)
    puts "!!after_enqueue_foo!! #{args.inspect}"
  end

  def self.after_enqueue_bar(*args)
    raise HookFailError, "Fail HookedObjectAfterEnqueueFail"
  end
end

class HookedObjectBeforePerformFail
  include Backburner::Performable

  def self.before_perform_abe(*args)
    puts "!!before_perform_foo!! #{args.inspect}"
  end

  def self.before_perform_foo(*args)
    return false
  end

  def self.foo(x)
    puts "Fail ran!!"
    raise HookFailError, "HookedObjectJobFailure on foo!"
  end
end

class HookedObjectAfterPerformFail
  def self.after_perform_abe(*args)
    puts "!!after_perform_foo!! #{args.inspect}"
  end

  def self.after_perform_bar(*args)
    raise HookFailError, "Fail HookedObjectAfterEnqueueFail"
  end
end

class HookedObjectJobFailure
  def self.foo(x)
    raise HookFailError, "HookedObjectJobFailure on foo!"
  end
end

class HookedObjectSuccess
  include Backburner::Performable

  def self.before_enqueue_foo(*args)
    puts "!!before_enqueue_foo!! #{args.inspect}"
  end

  def self.before_enqueue_bar(*args)
    puts "!!before_enqueue_bar!! #{args.inspect}"
  end

  def self.after_enqueue_foo(*args)
    puts "!!after_enqueue_foo!! #{args.inspect}"
  end

  def self.after_enqueue_bar(*args)
    puts "!!after_enqueue_bar!! #{args.inspect}"
  end

  def self.before_perform_foo(*args)
    puts "!!before_perform_foo!! #{args.inspect}"
  end

  def self.after_perform_foo(*args)
    puts "!!after_perform_foo!! #{args.inspect}"
  end

  def self.around_perform_bar(*args)
    puts "!!BEGIN around_perform_bar!! #{args.inspect}"
    yield
    puts "!!END around_perform_bar!! #{args.inspect}"
  end

  def self.around_perform_cat(*args)
    puts "!!BEGIN around_perform_cat!! #{args.inspect}"
    yield
    puts "!!END around_perform_cat!! #{args.inspect}"
  end

  def self.on_failure_foo(ex, *args)
    puts "!!on_failure_foo!! #{ex.inspect} #{args.inspect}"
  end

  def self.foo(x)
    $hooked_fail_count += 1
    raise HookFailError, "Fail!" if $hooked_fail_count == 1
    puts "This is the job running successfully!! #{x.inspect}"
  end
end # HookedObjectSuccess