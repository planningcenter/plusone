require 'sidekiq'
require_relative '../app'

class UpdatePendingChecksJob
  include Sidekiq::Worker

  def perform(payload)
    update_pending_checks(payload)
  end
end
