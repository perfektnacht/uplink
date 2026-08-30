class NodesController < ApplicationController
  before_action :set_node, only: %i[ edit update destroy ]

  def new
    @node = Node.new(kind: "host", probe_kind: "icmp", x: 120, y: 120, width: 240)
  end

  def edit
  end

  def create
    @node = Node.new(node_params)

    if @node.save
      close_inspector
    else
      render :new, status: :unprocessable_entity
    end
  end

  # Also where a drag lands, which is why it happily accepts a body containing
  # nothing but x and y. The card redraws itself from the model's broadcast, so
  # a drag needs no response beyond "saved".
  def update
    if @node.update(node_params)
      respond_to do |format|
        format.json { head :no_content }
        format.html { close_inspector }
      end
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @node.destroy!
    close_inspector
  end

  private
    def set_node = @node = Node.find(params[:id])

    def close_inspector
      render turbo_stream: turbo_stream.update("inspector", "")
    end

    def node_params
      params.require(:node).permit(:name, :kind, :address, :x, :y, :width, :notes,
        :probe_kind, :probe_port, :probe_url, :probe_interval)
    end
end
