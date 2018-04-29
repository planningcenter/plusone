require 'sidekiq'
require_relative '../app'

class AssignOwnerJob
  include Sidekiq::Worker

  def perform(payload)
    sleep 0.5 # give their API just a bit to get caught up
    assign_owner(payload)
  end
end
