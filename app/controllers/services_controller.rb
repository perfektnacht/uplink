class ServicesController < ApplicationController
  before_action :set_service, only: %i[ edit update destroy ]

  def new
    @node = Node.find(params[:node_id])
    @service = @node.services.build(probe_kind: "http")
  end

  def edit
  end

  def create
    @node = Node.find(params[:node_id])
    @service = @node.services.build(service_params)

    if @service.save
      close_inspector
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @service.update(service_params)
      close_inspector
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @service.destroy!
    close_inspector
  end

  private
    def set_service = @service = Service.find(params[:id])

    # A form inside a turbo-frame submits as a frame navigation, and Turbo
    # looks for a matching frame in the reply. Answering with a turbo-stream
    # instead leaves it with nothing to swap, and it renders the string
    # "Content missing" where the form used to be. An empty frame is the
    # response that actually means "done, close this".
    def close_inspector
      render html: helpers.turbo_frame_tag("inspector"), layout: false
    end

    def service_params
      params.require(:service).permit(:name, :url, :icon, :position,
        :probe_kind, :probe_port, :probe_url, :probe_interval)
    end
end
