# The network as a tree. Same rows as the canvas, read a second way.
class GroveController < ApplicationController
  def show
    @grove = Grove.draw
  end
end
