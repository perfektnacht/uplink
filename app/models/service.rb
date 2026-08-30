# A link to something you actually use, living inside the node that runs it.
# Its status is its own: a container can be down on a host that is fine.
class Service < ApplicationRecord
  include Probeable

  belongs_to :node

  validates :name, :url, presence: true
  validates :probe_interval, numericality: { in: 10..86_400 }

  before_validation :default_position, on: :create

  scope :ordered, -> { order(:position, :id) }

  # Services are drawn inside their node, so any change to one redraws that
  # node — but only when the change is visible. See Node#worth_redrawing?.
  after_create_commit  -> { redraw_node }
  after_update_commit  -> { redraw_node if worth_redrawing? }
  after_destroy_commit -> { redraw_node }

  def host = URI.parse(url).host rescue nil

  def worth_redrawing?
    (saved_changes.keys - %w[ last_probed_at latency_ms updated_at ]).any?
  end

  private
    def redraw_node
      broadcast_replace_later_to "canvas", target: node, partial: "nodes/node",
        locals: { node: node }
    end

    def http_target = url
    def address = host

    def default_position
      self.position = node&.services&.maximum(:position).to_i + 1 if position.to_i.zero?
    end
end
