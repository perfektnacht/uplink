class LinksController < ApplicationController
  def create
    Link.create!(params.require(:link).permit(:from_node_id, :to_node_id, :kind))
    head :created
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
    head :unprocessable_entity
  end

  def destroy
    Link.find(params[:id]).destroy!
    head :no_content
  end
end
