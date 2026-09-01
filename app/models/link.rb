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

  # A logical link is drawn as a chip on the card it hangs from, not as a line
  # in the cable layer, so renaming one has to redraw that card. Without this
  # the chip goes on saying DNS until something else redraws the node.
  after_update_commit -> { redraw_chip if logical? && (saved_changes.keys & %w[ label kind from_node_id ]).any? }

  # The grove draws cables and dependencies in different halves of the picture
  # — a cable is a branch, a logical link is a root — so either one changing
  # changes the shape of the tree. Nodes have said this for themselves since
  # the grove existed; links never did, and a new Pi-hole appeared on the
  # canvas while the grove went on showing the network without it.
  after_commit -> { Grove.redraw if worth_regrowing? }

  # Live means nothing along this cable is known to be broken, not that both
  # ends answered. An unmanaged switch answers nothing and never will; letting
  # it grey out the whole chain behind it would report ignorance as failure.
  def live?
    return false if from_node.status_down? || to_node.status_down?
    from_node.status_up? || to_node.status_up?
  end

  # Which end a cable runs between, and whether it is a cable at all. Nothing
  # else about a link is in the picture.
  def worth_regrowing?
    destroyed? || (saved_changes.keys & %w[ id kind label from_node_id to_node_id ]).any?
  end

  private
    def redraw_chip
      [ from_node_id, from_node_id_before_last_save ].compact.uniq.each do |id|
        node = Node.find_by(id: id) or next
        broadcast_replace_later_to "canvas", target: node, partial: "nodes/node",
          locals: { node: node }
      end
    end

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
