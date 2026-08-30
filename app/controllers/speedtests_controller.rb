class SpeedtestsController < ApplicationController
  # Measuring takes half a minute and moves real traffic, so the request
  # returns immediately and the number arrives over the stream when it exists.
  def create
    SpeedtestJob.perform_later
    head :accepted
  end
end
