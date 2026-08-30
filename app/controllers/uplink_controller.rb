class UplinkController < ApplicationController
  def show
    @nodes = Node.ordered.includes(:services, outgoing_links: :to_node)
    # Logical links are drawn on the cards that use them, not as cables.
    @links = Link.where.not(kind: "logical").includes(:from_node, :to_node)
    @speedtest = Speedtest.latest
  end
end
