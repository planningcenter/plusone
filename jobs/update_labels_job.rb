require 'sidekiq'
require_relative '../app'

class UpdateLabelsJob
  include Sidekiq::Worker

  def perform(payload)
    sleep 0.5 # give their API just a bit to get caught up
    update_labels(payload)
  end
end
