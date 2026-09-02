class NodesController < ApplicationController
  before_action :set_node, only: %i[ edit update destroy ]

  def new
    x, y = Node.free_position(within: viewport)
    @node = Node.new(kind: "host", probe_kind: "icmp", x: x, y: y, width: 240)
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
    # Where the canvas says it is looking, as "x,y,w,h" in sheet coordinates.
    # Absent -- no javascript, or the form reached some other way -- placement
    # falls back to walking down the left edge.
    def viewport
      box = params[:in].to_s.split(",").map { |n| Integer(n, exception: false) }
      return nil unless box.size == 4 && box.all? && box[2].positive? && box[3].positive?

      { x: box[0], y: box[1], width: box[2], height: box[3] }
    end

    def set_node = @node = Node.find(params[:id])

    # A form inside a turbo-frame submits as a frame navigation, and Turbo
    # looks for a matching frame in the reply. Answering with a turbo-stream
    # instead leaves it with nothing to swap, and it renders the string
    # "Content missing" where the form used to be. An empty frame is the
    # response that actually means "done, close this".
    def close_inspector
      render html: helpers.turbo_frame_tag("inspector"), layout: false
    end

    def node_params
      params.require(:node).permit(:name, :kind, :address, :x, :y, :width, :notes,
        :probe_kind, :probe_port, :probe_url, :probe_interval)
    end
end
