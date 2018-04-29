require 'sidekiq'
require_relative '../app'

class PlusOneJob
  include Sidekiq::Worker

  def perform(payload)
    sleep 0.5 # give their API just a bit to get caught up
    case payload['action']
    when 'opened'
      assign_owner(payload)
    when 'created', 'submitted'
      update_labels(payload)
    end
  end
end
