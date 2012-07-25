# require 'echelon/tasks'
# will give you the echelon tasks

namespace :echelon do
  # QUEUE=foo,bar,baz rake echelon:work
  desc "Start an echelon worker"
  task :work => :environment do
    queues = (ENV["QUEUE"] ? ENV["QUEUE"].split(',') : nil) rescue nil
    Echelon.work! queues
  end
end