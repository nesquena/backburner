module Backburner
  class Hooks
    class << self
      # Triggers all method hooks that match the given event type with specified arguments.
      #
      # @example
      #   invoke_hook_events(hookable, :before_enqueue, 'some', 'args')
      #   invoke_hook_events(hookable, :after_perform, 5)
      #
      def invoke_hook_events(hookable, event, *args)
        res = find_hook_events(hookable, event).map { |e| hookable.send(e, *args) }
        return false if res.any? { |result| result == false }
        res
      end

      # Triggers all method hooks that match given around event type. Used for 'around' hooks
      # that stack over the original task cumulatively onto one another.
      #
      # The final block will be the one that actually invokes the
      # original task after calling all other around blocks.
      #
      # @example
      #   around_hook_events(hookable, :around_perform) { hookable.perform }
      #
      def around_hook_events(hookable, event, *args, &block)
        raise "Please pass a block to hook events!" unless block_given?
        around_hooks = find_hook_events(hookable, event).reverse
        aggregate_filter = Proc.new { |&blk| blk.call }
        around_hooks.each do |ah|
          prior_around_filter = aggregate_filter
          aggregate_filter = Proc.new do |&blk|
            hookable.method(ah).call(*args) do
              prior_around_filter.call(&blk)
            end
          end
        end
        aggregate_filter.call(&block)
      end

      protected

      # Returns all methods that match given hook type
      #
      # @example
      #   find_hook_events(:before_enqueue)
      #   # => ['before_enqueue_foo', 'before_enqueue_bar']
      #
      def find_hook_events(hookable, event)
        pattern = HOOK_PATTERNS[event] || /^#{event}/
        (class_hook_events(hookable, pattern) || (hookable.methods - Object.methods).grep(pattern)).sort
      end

      # The names (hookable.methods - Object.methods).grep(pattern) gives for a class, without listing every method
      # each class has: a class's methods are looked up in its own modules (its singleton class, its superclasses'
      # and the modules they extend) and then in Object's, so a name none of its own modules define is looked up
      # as on Object, and Object.methods has it too. nil for anything else (an instance, a module, a class that
      # doesn't end in Object's modules or that doesn't list its methods with Kernel#methods).
      def class_hook_events(hookable, pattern)
        return unless Class === hookable
        singleton = SINGLETON_CLASS.bind_call(hookable)
        return unless PUBLIC_METHOD_DEFINED.bind_call(singleton, :methods)
        listing = INSTANCE_METHOD.bind_call(singleton, :methods)
        return unless listing.owner.equal?(Kernel) && listing.original_name == :methods && listing.source_location.nil?
        object = Object.singleton_class
        ancestors = ANCESTORS.bind_call(singleton)
        objects = ANCESTORS.bind_call(object)
        own = ancestors.size - objects.size
        return unless own > 0 && ancestors.last(objects.size) == objects
        # a name the class lists is public or protected where it is looked up, so one of them lists it
        names = ancestors.first(own).flat_map { |mod| INSTANCE_METHODS.bind_call(mod, false).grep(pattern) }
        names.uniq.select { |name| listed?(singleton, name) && !listed?(object, name) }
      end

      # Whether an object whose singleton class is `singleton` lists the method in #methods (a public or protected one)
      def listed?(singleton, name)
        PUBLIC_METHOD_DEFINED.bind_call(singleton, name) || PROTECTED_METHOD_DEFINED.bind_call(singleton, name)
      end

      # The patterns of the events Backburner triggers, compiled once
      HOOK_PATTERNS = %i[before_enqueue after_enqueue before_perform around_perform after_perform on_failure on_bury
        on_retry on_reconnect].to_h { |event| [event, /^#{event}/] }.freeze

      # Kernel's and Module's own reflection, whatever a class or module defines for itself
      SINGLETON_CLASS = Kernel.instance_method(:singleton_class)
      ANCESTORS = Module.instance_method(:ancestors)
      INSTANCE_METHODS = Module.instance_method(:instance_methods)
      INSTANCE_METHOD = Module.instance_method(:instance_method)
      PUBLIC_METHOD_DEFINED = Module.instance_method(:public_method_defined?)
      PROTECTED_METHOD_DEFINED = Module.instance_method(:protected_method_defined?)
    end
  end # Hooks
end # Backburner
