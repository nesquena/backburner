module Backburner
  module Helpers
    # Loads in instance and class levels
    def self.included(base)
      base.extend self
    end

    # Prints out exception_message based on specified e
    def exception_message(e)
      msg = [ "Exception #{e.class} -> #{e.message}" ]

      base = File.expand_path(Dir.pwd) + '/'
      e.backtrace.each do |t|
        msg << "   #{File.expand_path(t).gsub(/#{base}/, '')}"
      end if e.backtrace

      msg.join("\n")
    end

    # Given a word with dashes, returns a camel cased version of it.
    #
    # @example
    #   classify('job-name') # => 'JobName'
    #
    def classify(dashed_word)
      dashed_word.to_s.split('-').each { |part| part[0] = part[0].chr.upcase }.join
    end

    # Given a class, dasherizes the name, used for getting tube names
    #
    # @example
    #   dasherize('JobName') # => "job-name"
    #
    def dasherize(word)
      classify(word).to_s.gsub(/::/, '/').
            gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
            gsub(/([a-z\d])([A-Z])/,'\1_\2').
            tr("_", "-").downcase
    end

    # Tries to find a constant with the name specified in the argument string:
    #
    # @example
    #   constantize("Module") # => Module
    #   constantize("Test::Unit") # => Test::Unit
    #
    # NameError is raised when the constant is unknown.
    def constantize(camel_cased_word)
      camel_cased_word = camel_cased_word.to_s

      if camel_cased_word.include?('-')
        camel_cased_word = classify(camel_cased_word)
      end

      names = camel_cased_word.split('::')
      names.shift if names.empty? || names.first.empty?

      constant = Object
      names.each do |name|
        args = Module.method(:const_get).arity != 1 ? [false] : []

        if constant.const_defined?(name, *args)
          constant = constant.const_get(name)
        else
          constant = constant.const_missing(name)
        end
      end
      constant
    end

    # Returns configuration options for backburner
    #
    # @example
    #   config.max_job_retries => 3
    #
    def config
      Backburner.configuration
    end

    # Expands a tube to include the prefix
    #
    # @example
    #   expand_tube_name("foo") # => <prefix>.foo
    #   expand_tube_name(FooJob) # => <prefix>.foo-job
    #
    def expand_tube_name(tube)
      prefix = config.tube_namespace
      queue_name = if tube.is_a?(String)
        tube
      elsif tube.respond_to?(:queue) # use queue name
        tube.queue
      elsif tube.is_a?(Class) # no queue name, use job_class
        tube.name
      else # turn into a string
        tube.to_s
      end
      [prefix.gsub(/\.$/, ''), dasherize(queue_name).gsub(/^#{prefix}/, '')].join(".").gsub(/\.+/, '.')
    end

  end
end