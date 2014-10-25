require 'dante'

module Backburner
  class CLI

    def self.start(args)
      runner = Dante::Runner.new('backburner')
      runner.description = "Execute a backburner worker process"
      runner.with_options do |opts|
        opts.on("-r", "--require PATH", String, "The path to load as the environment.") do |req|
          options[:require] = req
        end
        opts.on("-q", "--queues PATH", String, "The specific queues to work.") do |queues|
          options[:queues] = queues
        end
      end
      runner.execute do |opts|
        queues = (opts[:queues] ? opts[:queues].split(',') : nil) rescue nil
        load_enviroment(opts[:require])
        Backburner.work(queues)
      end
    end

    protected

      def self.load_enviroment(file = nil)
        file ||= "."
        if File.directory?(file) && File.exists?(File.expand_path("#{file}/config/environment.rb"))
          require "rails"
          require File.expand_path("#{file}/config/environment.rb")
          if defined?(::Rails) && ::Rails.respond_to?(:application)
            # Rails 3
            ::Rails.application.eager_load!
          elsif defined?(::Rails::Initializer)
            # Rails 2.3
            $rails_rake_task = false
            ::Rails::Initializer.run :load_application_classes
          end
        elsif File.directory?(file) && File.exists?(File.expand_path("#{file}/config/boot.rb"))
          if defined?(::Padrino)
            # Padrino
            require "padrino"
            require File.expand_path("#{file}/config/boot.rb")
          end
        elsif File.file?(file)
          require File.expand_path(file)
        end
      end

  end
end
