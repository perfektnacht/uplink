# A cable between two nodes. `logical` is for a relationship that is real but
# not physical — the router pointing at Pi-hole for DNS travels over the same
# ethernet as everything else, and drawing it as another wire would be a lie.
class Link < ApplicationRecord
  KINDS = %w[ ethernet wifi coax fiber logical ].freeze

  belongs_to :from_node, class_name: "Node"
  belongs_to :to_node,   class_name: "Node"

  validates :kind, inclusion: { in: KINDS }
  validate  :not_a_loop
  validate  :not_already_cabled

  # A logical link is a node saying "I use that one for something". It is
  # drawn as a chip on the card that uses the service, because the relationship
  # is many-to-one — every machine on the network can point at one Pi-hole, and
  # a line from each of them would be noise, not information.
  scope :logical, -> { where(kind: "logical") }

  def logical? = kind == "logical"
  def caption = label.presence || to_node.name

  after_create_commit  -> { broadcast_append_later_to "canvas", target: "links" }
  after_destroy_commit -> { broadcast_remove_to "canvas" }

  # Live means nothing along this cable is known to be broken, not that both
  # ends answered. An unmanaged switch answers nothing and never will; letting
  # it grey out the whole chain behind it would report ignorance as failure.
  def live?
    return false if from_node.status_down? || to_node.status_down?
    from_node.status_up? || to_node.status_up?
  end

  private
    def not_a_loop
      errors.add(:to_node, "is the same node") if from_node_id == to_node_id
    end

    # The unique index catches an exact repeat, but a cable is the same cable
    # whichever end you started dragging from. Without this, wiring B back to A
    # quietly draws a second line on top of the first.
    def not_already_cabled
      existing = Link.where(from_node_id: to_node_id, to_node_id: from_node_id)
      existing = existing.where.not(id: id) if persisted?

      errors.add(:base, "these are already cabled together") if existing.exists?
    end
end
