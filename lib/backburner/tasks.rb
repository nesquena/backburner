# require 'backburner/tasks'
# will give you the backburner tasks

namespace :backburner do
  # QUEUE=foo,bar,baz rake backburner:work
  desc "Start an backburner worker"
  task :work => :environment do
    queues = (ENV["QUEUE"] ? ENV["QUEUE"].split(',') : nil) rescue nil
    Backburner.work queues
  end
end