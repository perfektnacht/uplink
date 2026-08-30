# A piece of gear on the canvas: the internet itself, the modem it arrives
# through, the router, a switch, a machine, an appliance. Where it sits is
# stored rather than computed, because you put it there.
class Node < ApplicationRecord
  include Probeable

  # Suggestions, not a closed set. A fixed enum kept failing real networks —
  # a Pi-hole is not an appliance, a Hue bridge is not either — and every miss
  # cost a migration. Kind is free text; these are what the field offers.
  KINDS = [
    "internet", "modem", "router", "switch", "access point",
    "desktop", "laptop", "mini pc", "raspberry pi", "server", "vps",
    "nas", "smart home hub", "camera", "printer", "appliance"
  ].freeze

  has_many :services, -> { order(:position) }, dependent: :destroy
  has_many :outgoing_links, class_name: "Link", foreign_key: :from_node_id, dependent: :destroy
  has_many :incoming_links, class_name: "Link", foreign_key: :to_node_id,   dependent: :destroy

  validates :name, presence: true
  validates :kind, presence: true, length: { maximum: 40 }
  validates :width, numericality: { in: 160..640 }
  validates :probe_interval, numericality: { in: 10..86_400 }

  scope :ordered, -> { order(:position, :id) }

  # Somewhere the new card will not land on top of an existing one. Height is
  # not stored — a card is as tall as its contents — so this assumes a generous
  # one and walks down a column until it finds a gap.
  ROW = 160
  ASSUMED_HEIGHT = 150

  def self.free_position(x: 120, y: 120, width: 240)
    taken = pluck(:x, :y, :width)

    while taken.any? { |ox, oy, ow|
      x < ox + ow && x + width > ox && y < oy + ASSUMED_HEIGHT && y + ASSUMED_HEIGHT > oy
    }
      y += ROW
    end

    [ x, y ]
  end

  after_create_commit  -> { broadcast_prepend_later_to "canvas", target: "nodes" }
  after_update_commit  -> { broadcast_replace_later_to "canvas" if worth_redrawing? }
  after_destroy_commit -> { broadcast_remove_to "canvas" }

  # The grove draws the same rows a different way, so it redraws for the same
  # reasons — but only for the changes that alter its shape.
  after_commit -> { Grove.redraw if worth_regrowing? }

  # A tree changes when something is up, down, added, removed or renamed. It
  # does not change because a probe stamped the time again.
  def worth_regrowing?
    destroyed? || (saved_changes.keys & %w[ id name kind status ]).any?
  end

  def links = Link.where(from_node_id: id).or(Link.where(to_node_id: id))

  # The services this node consumes from elsewhere: DNS from a Pi-hole, time
  # from a router. Drawn on the card rather than as cables.
  def uses = outgoing_links.select(&:logical?)

  def internet? = kind == "internet"

  # A node is only as up as the things inside it: a host answering pings while
  # every container on it is dead is not a green dot.
  def rollup_status
    return status if services.none?
    return "down" if status_down?
    services.any?(&:status_down?) ? "warn" : status
  end

  # A probe that finds nothing changed still stamps last_probed_at, and a
  # service touching its host still bumps updated_at. Neither is news. Redraw
  # only when something a person would notice actually moved.
  def worth_redrawing?
    (saved_changes.keys - %w[ last_probed_at latency_ms updated_at ]).any?
  end

  private
    def http_target = probe_url.presence || (address.present? ? "http://#{address}" : nil)
end
