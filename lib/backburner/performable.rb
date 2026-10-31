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

      # Always handle an instance method asynchronously
      # @example
      #   User.handle_asynchronously :send_welcome_email, queue: 'send-mail', delay: 10
      def handle_asynchronously(method, opts={})
        Backburner::Performable.handle_asynchronously(self, method, opts)
      end

      # Always handle a class method asynchronously
      # @example
      #   User.handle_static_asynchronously :update_recent_visitors, ttr: 300
      def handle_static_asynchronously(method, opts={})
        Backburner::Performable.handle_static_asynchronously(self, method, opts)
      end
    end # ClassMethods


    # Make all calls to an instance method asynchronous. The given opts will be passed
    # to the async method.
    # @example
    #   Backburner::Performable.handle_asynchronously(MyObject, :long_task, queue: 'long-tasks')
    # NB: The method called on the async proxy will be ""#{method}_without_async". This
    # will also be what's given to the Worker.enqueue method so your workers need
    # to know about that. It shouldn't be a problem unless the producer and consumer are
    # from different codebases (or anywhere they don't both call the handle_asynchronously
    # method when booting up)
    def self.handle_asynchronously(klass, method, opts={})
      _handle_asynchronously(klass, klass, method, opts)
    end

    # Make all calls to a class method asynchronous. The given opts will be passed
    # to the async method. Please see the NB on #handle_asynchronously
    def self.handle_static_asynchronously(klass, method, opts={})
      _handle_asynchronously(klass, klass.singleton_class, method, opts)
    end

    def self._handle_asynchronously(klass, klass_eval_scope, method, opts={})
      aliased_method, punctuation = method.to_s.sub(/([?!=])$/, ''), $1
      with_async_name    = :"#{aliased_method}_with_async#{punctuation}"
      without_async_name = :"#{aliased_method}_without_async#{punctuation}"

      klass.send(:include, Performable) unless klass.included_modules.include?(Performable)
      klass_eval_scope.class_eval do
        define_method with_async_name do |*args|
          async(opts).__send__ without_async_name, *args
        end
        alias_method without_async_name, method.to_sym
        alias_method method.to_sym, with_async_name
      end
    end
    private_class_method :_handle_asynchronously


  end # Performable
end # Backburner
