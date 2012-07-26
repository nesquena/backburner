require 'backburner/async_proxy'

module Backburner
  module Performable
    def self.included(base)
      base.send(:include, InstanceMethods)
      base.send(:include, Backburner::Queue)
      base.extend ClassMethods
    end

    module InstanceMethods
      # Return proxy object to enqueue jobs for object
      # Options: `pri` (priority), `delay` (delay in secs), `ttr` (time to respond), `queue` (queue name)
      # @example
      #   @model.async(:pri => 1000).do_something("foo")
      #
      def async(opts={})
        Backburner::AsyncProxy.new(self.class, self.id, opts)
      end
    end # InstanceMethods

    module ClassMethods
      # Return proxy object to enqueue jobs for object
      # Options: `pri` (priority), `delay` (delay in secs), `ttr` (time to respond), `queue` (queue name)
      # @example
      #   Model.async(:ttr => 300).do_something("foo")
      def async(opts={})
        Backburner::AsyncProxy.new(self, nil, opts)
      end

      # Defines perform method for job processing
      # @example
      #   perform(55, :do_something, "foo", "bar")
      def perform(id, method, *args)
        if id # instance
          find(id).send(method, *args)
        else # class method
          send(method, *args)
        end
      end # perform
    end # ClassMethods

  end # Performable
end # Backburner
