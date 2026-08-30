# What the internet was doing the last time you asked. Never on a timer by
# default: a dashboard that saturates the line it is measuring is a bad joke.
class Speedtest < ApplicationRecord
  scope :recent, -> { order(created_at: :desc) }

  def self.latest = recent.first

  # The moon is the reading, so a new reading is a new moon.
  after_commit -> { Grove.redraw if saved_change_to_down_mbps? || saved_change_to_error? }

  def ok? = error.blank?
end
