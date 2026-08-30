# What the internet was doing the last time you asked. Never on a timer by
# default: a dashboard that saturates the line it is measuring is a bad joke.
class Speedtest < ApplicationRecord
  scope :recent, -> { order(created_at: :desc) }

  def self.latest = recent.first

  def ok? = error.blank?
end
