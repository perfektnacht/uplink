# A piece of gear on the canvas: the internet itself, the modem it arrives
# through, the router, a switch, a machine, an appliance. Where it sits is
# stored rather than computed, because you put it there.
class Node < ApplicationRecord
  include Probeable

  # `host` is anything you log into and run things on — a server, a NAS, a
  # Raspberry Pi serving DNS. `appliance` is the gear that does one job and
  # that you never administer: an access point, a printer, a managed PDU.
  KINDS = %w[ internet modem router switch host appliance ].freeze

  has_many :services, -> { order(:position) }, dependent: :destroy
  has_many :outgoing_links, class_name: "Link", foreign_key: :from_node_id, dependent: :destroy
  has_many :incoming_links, class_name: "Link", foreign_key: :to_node_id,   dependent: :destroy

  validates :name, presence: true
  validates :kind, inclusion: { in: KINDS }
  validates :width, numericality: { in: 160..640 }
  validates :probe_interval, numericality: { in: 10..86_400 }

  scope :ordered, -> { order(:position, :id) }

  after_create_commit  -> { broadcast_prepend_later_to "canvas", target: "nodes" }
  after_update_commit  -> { broadcast_replace_later_to "canvas" if worth_redrawing? }
  after_destroy_commit -> { broadcast_remove_to "canvas" }

  def links = Link.where(from_node_id: id).or(Link.where(to_node_id: id))

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
