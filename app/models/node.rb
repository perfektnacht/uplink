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

  # How finely the visible rectangle is searched. Coarse enough to be quick,
  # fine enough to find the gap between two cards.
  SCAN = 40

  # `within` is where the browser says it is looking, in sheet coordinates. The
  # sheet is 4000x3000 and the network is rarely near its corner, so without it
  # a new card is placed somewhere true and invisible.
  def self.free_position(x: 120, y: 120, width: 240, within: nil)
    taken = pluck(:x, :y, :width)
    clear = ->(cx, cy) {
      taken.none? { |ox, oy, ow|
        cx < ox + ow && cx + width > ox && cy < oy + ASSUMED_HEIGHT && cy + ASSUMED_HEIGHT > oy
      }
    }

    if within && (spot = first_gap_in(within, width, &clear))
      return spot
    end

    y += ROW until clear.(x, y)
    [ x, y ]
  end

  # The visible rectangle in reading order, first gap wins. Nil when the whole
  # of it is covered, or when it is too small to hold a card at all — a deep
  # zoom on one machine, say — and then the caller falls back to the walk.
  def self.first_gap_in(within, width)
    last_x = within[:x] + within[:width] - width
    last_y = within[:y] + within[:height] - ASSUMED_HEIGHT
    return nil if last_x < within[:x] || last_y < within[:y]

    within[:y].step(last_y, SCAN) do |cy|
      within[:x].step(last_x, SCAN) do |cx|
        return [ cx.round, cy.round ] if yield(cx, cy)
      end
    end

    nil
  end
  private_class_method :first_gap_in

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
