class LinksController < ApplicationController
  before_action :set_link, only: %i[ edit update destroy ]

  def edit
  end

  def create
    Link.create!(params.require(:link).permit(:from_node_id, :to_node_id, :kind, :label))
    head :created
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
    head :unprocessable_entity
  end

  def update
    if @link.update(link_params)
      close_inspector
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @link.destroy!
    close_inspector
  end

  private
    def set_link = @link = Link.find(params[:id])

    def close_inspector
      render html: helpers.turbo_frame_tag("inspector"), layout: false
    end

    def link_params = params.require(:link).permit(:kind, :label, :from_node_id, :to_node_id)
end
