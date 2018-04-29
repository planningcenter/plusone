require 'sidekiq'
require_relative '../app'

class ApplyStagingLabelJob
  include Sidekiq::Worker

  def perform(payload)
    apply_staging_label(payload)
  end
end
