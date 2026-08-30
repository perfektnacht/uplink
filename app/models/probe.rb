# One reading, kept only long enough to be useful.
class Probe < ApplicationRecord
  belongs_to :probeable, polymorphic: true

  scope :stale, -> { where(created_at: ...24.hours.ago) }

  def self.prune = stale.delete_all
end
