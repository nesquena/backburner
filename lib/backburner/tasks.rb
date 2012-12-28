# require 'backburner/tasks'
# will give you the backburner tasks

namespace :backburner do
  # QUEUE=foo,bar,baz rake backburner:work
  desc "Start backburner worker using default worker"
  task :work => :environment do
    queues = (ENV["QUEUE"] ? ENV["QUEUE"].split(',') : nil) rescue nil
    Backburner.work queues
  end

  namespace :simple do
    # QUEUE=foo,bar,baz rake backburner:simple:work
    desc "Starts backburner worker using simple processing"
    task :work => :environment do
      queues = (ENV["QUEUE"] ? ENV["QUEUE"].split(',') : nil) rescue nil
      Backburner.work queues, :worker => Backburner::Workers::Simple
    end
  end # simple

  namespace :forking do
    # QUEUE=foo,bar,baz rake backburner:forking:work
    desc "Starts backburner worker using fork processing"
    task :work => :environment do
      queues = (ENV["QUEUE"] ? ENV["QUEUE"].split(',') : nil) rescue nil
      Backburner.work queues, :worker => Backburner::Workers::Forking
    end
  end # forking

  namespace :threads_on_fork do
    # QUEUE=twitter:10:5000:5,parse_page,send_mail,verify_bithday THREADS=2 GARBAGE=1000 rake backburner:threads_on_fork:work
    # twitter tube will have 10 threads, garbage after 5k executions and retry 5 times.
    desc "Starts backburner worker using threads_on_fork processing"
    task :work => :environment do
      queues = (ENV["QUEUE"] ? ENV["QUEUE"].split(',') : nil) rescue nil
      threads = ENV['THREADS'].to_i
      garbage = ENV['GARBAGE'].to_i
      Backburner::Workers::ThreadsOnFork.threads_number = threads if threads > 0
      Backburner::Workers::ThreadsOnFork.garbage_after  = garbage if garbage > 0
      Backburner.work queues, :worker => Backburner::Workers::ThreadsOnFork
    end
  end # threads_on_fork
end