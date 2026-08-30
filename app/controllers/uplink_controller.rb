class UplinkController < ApplicationController
  def show
    @nodes = Node.ordered.includes(:services)
    @links = Link.includes(:from_node, :to_node)
    @speedtest = Speedtest.latest
  end
end
