require 'sinatra/base'

module Backburner
  class Web < Sinatra::Base

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

    get '/monitoring' do
      content_type :json
      { :todo => 'not yet implemented' }.to_json
    end

    get '/configuration' do
      content_type :json
      c = Backburner.configuration
      { :beanstalk_url => c.beanstalk_url, 
        :tube_namespace => c.tube_namespace,
        :default_priority => c.default_priority,
        :respond_timeout => c.respond_timeout,
        :max_job_retries => c.max_job_retries,
        :default_queues => c.default_queues,
        :default_worker => c.default_worker.class.to_s }.to_json
    end
  end
end