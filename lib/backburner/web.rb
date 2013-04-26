require 'sinatra/base'

module Backburner
  class Web < Sinatra::Base

    MAX_JOBS_FOR_DISPLAY = 100

    root = File.expand_path(File.dirname(__FILE__) + "/../../web")
    set :root, root
    set :views,  "#{root}/views"
    set :public_folder, "#{root}/dist"
    set :static, true

    get '/' do
      redirect url("/index.html")
    end

    not_found do
      redirect url("/404.html")
    end

    get '/stats' do
      content_type :json
      connection = Connection.new(Backburner.configuration.beanstalk_url)
      existing_tubes  = connection.tubes.all.select { |tube| tube.name =~ /^#{Backburner.configuration.tube_namespace}/ }
      stats = stats_to_hash(connection.stats)
      existing_tubes.each do |tube|
        stats["queues"] << tube_stats_to_hash(tube.stats, tube.name)
      end
      stats.to_json
    end

    get '/queue/:name/jobs' do
      content_type :json
      connection = Connection.new(Backburner.configuration.beanstalk_url)
      jobs = get_jobs_for_display(connection, params[:name])
      ret_jobs = []
      jobs.each do |job|
        ret_jobs << job_to_hash(job)
        job.release
      end
      ret_jobs.to_json
    end

    get '/configuration' do
      content_type :json
      c = Backburner.configuration
      { :version => Backburner::VERSION,
        :beanstalk_url => c.beanstalk_url, 
        :tube_namespace => c.tube_namespace,
        :default_priority => c.default_priority,
        :respond_timeout => c.respond_timeout,
        :max_job_retries => c.max_job_retries,
        :retry_delay => c.retry_delay,
        :default_queues => c.default_queues,
        :default_worker => c.default_worker.class.to_s }.to_json
    end

    def get_jobs_for_display(connection, tube_name)
      jobs = []
      tubes = connection.tubes
      tubes.watch(tube_name)
      while (jobs.size < MAX_JOBS_FOR_DISPLAY)
        job = nil
        begin 
          jobs << tubes.reserve(1)
        rescue Beaneater::TimedOutError => e
          break
        end
      end
      jobs
    end

    def stats_to_hash(stats)
      hash = {}
      hash["current_jobs_urgent"] = stats["current_jobs_urgent"]
      hash["current_jobs_ready"] = stats["current_jobs_ready"]
      hash["current_jobs_reserved"] = stats["current_jobs_reserved"]
      hash["current_jobs_delayed"] = stats["current_jobs_delayed"]
      hash["current_jobs_buried"] = stats["current_jobs_buried"]
      hash["job_timeouts"] = stats["job_timeouts"]
      hash["total_jobs"] = stats["total_jobs"]
      hash["current_connections"] = stats["current_connections"]
      hash["current_producers"] = stats["current_producers"]
      hash["current_workers"] = stats["current_workers"]
      hash["current_waiting"] = stats["current_waiting"]
      hash["queues"] = []
      hash
    end

    def tube_stats_to_hash(stats, tube_name)
      hash = {}
      hash["name"] = tube_name
      hash["current_jobs_urgent"] = stats["current_jobs_urgent"]
      hash["current_jobs_ready"] = stats["current_jobs_ready"]
      hash["current_jobs_reserved"] = stats["current_jobs_reserved"]
      hash["current_jobs_delayed"] = stats["current_jobs_delayed"]
      hash["current_jobs_buried"] = stats["current_jobs_buried"]
      hash["total_jobs"] = stats["total_jobs"]
      hash["current_using"] = stats["current_using"]
      hash["current_waiting"] = stats["current_waiting"]
      hash["current_watching"] = stats["current_watching"]
      hash
    end

    def job_to_hash(job)
      hash = {}
      job_stats = job.stats
      job_stats.keys.each { |key| hash[key] = job_stats[key] }
      hash['body'] = job.body.inspect
      hash
    end
  end
end