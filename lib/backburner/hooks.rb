module Backburner
  module Hooks
    # Triggers all method hooks that match the given event type with specified arguments.
    #
    # @example
    #   invoke_hook_events(:before_enqueue, 'some', 'args')
    #   invoke_hook_events(:after_perform, 5)
    #
    def invoke_hook_events(event, *args)
      res = find_hook_events(event).map { |e| send(e, *args) }
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
    #   around_hook_events(:around_perform) { job.perform }
    #
    def around_hook_events(event, *args, &block)
      raise "Please pass a block to hook events!" unless block_given?
      around_hooks = find_hook_events(event).reverse
      aggregate_filter = Proc.new { |&blk| blk.call }
      around_hooks.each do |ah|
        prior_around_filter = aggregate_filter
        aggregate_filter = Proc.new do |&blk|
          method(ah).call(*args) do
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
    def find_hook_events(event)
      (self.methods - Object.methods).grep(/^#{event}/).sort
    end
  end # Hooks
end # Backburner