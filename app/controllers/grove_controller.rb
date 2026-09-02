# The network as a tree. Same rows as the canvas, read a second way.
class GroveController < ApplicationController
  # No `Grove.draw` here. The scene is cached on what it is drawn from, and a
  # tree grown in the controller is a tree grown before anything has asked
  # whether the answer is already known -- which it usually is. The partial
  # draws one inside the cache block, on the misses only.
  def show
  end
end
