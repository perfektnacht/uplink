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

    def close_inspector
      render turbo_stream: turbo_stream.update("inspector", "")
    end

    def service_params
      params.require(:service).permit(:name, :url, :icon, :position,
        :probe_kind, :probe_port, :probe_url, :probe_interval)
    end
end
