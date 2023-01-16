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
        opts.on("-e", "--environment ENVIRONMENT", String, "The environment to run Backburner within") do |environment|
          options[:environment] = environment
        end
      end
      runner.execute do |opts|
        queues = (opts[:queues] ? opts[:queues].split(',') : nil) rescue nil
        load_environment(opts[:require], opts[:environment])
        Backburner.work(queues)
      end
    end

    protected

      def self.load_environment(file = nil, environment = nil)
        file ||= "."
        if File.directory?(file) && File.exist?(File.expand_path("#{file}/config/environment.rb"))
          ENV["RAILS_ENV"] = environment if environment && ENV["RAILS_ENV"].nil?
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
        elsif File.directory?(file) && File.exist?(File.expand_path("#{file}/config/boot.rb"))
          ENV["RACK_ENV"] = environment if environment && ENV["RACK_ENV"].nil?
          ENV["PADRINO_ROOT"] = file
          require File.expand_path("#{file}/config/boot.rb")
        elsif File.file?(file)
          require File.expand_path(file)
        end
      end

  end
end
