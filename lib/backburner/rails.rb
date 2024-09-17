require 'rails'
require 'active_job'
require 'active_job/queue_adapters/backburner_adapter'

module Backburner
  class Rails < ::Rails::Engine
  end
end
