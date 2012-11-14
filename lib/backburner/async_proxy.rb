module Backburner
  # BasicObject for 1.8.7
  class BasicObject
    instance_methods.each do |m|
      undef_method(m) if m.to_s !~ /(?:^__|^nil?$|^send$|^object_id$)/
    end
  end unless defined?(::BasicObject)

  # Class allows async task to be proxied
  class AsyncProxy < BasicObject
    # Options include `pri` (priority), `delay` (delay in secs), `ttr` (time to respond)
    #
    # @example
    #   AsyncProxy.new(User, 10, :pri => 1000, :ttr => 1000)
    #
    def initialize(klazz, id=nil, opts={})
      @klazz, @id, @opts = klazz, id, opts
    end

    # Enqueue as job when a method is invoked
    def method_missing(method, *args, &block)
      ::Backburner::Worker.enqueue(@klazz, [@id, method, *args], @opts)
    end
  end # AsyncProxy
end # Backburner