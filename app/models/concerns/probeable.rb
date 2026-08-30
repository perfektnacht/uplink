require "socket"
require "net/http"

# Anything on the canvas that can be up or down: a Node, or a Service inside one.
#
# The polling budget is the design constraint. A probe is one TCP handshake, one
# HEAD request, or one ICMP echo, once a minute per thing, and only for the
# things whose own interval has actually elapsed. A twenty-node network is
# twenty packets a minute — less than a phone sitting idle on the same wifi.
module Probeable
  extend ActiveSupport::Concern

  KINDS = %w[ none tcp http icmp ].freeze
  TIMEOUT = 3

  included do
    has_many :probes, as: :probeable, dependent: :delete_all

    enum :status, { unknown: "unknown", up: "up", down: "down" }, prefix: true

    normalizes :probe_url, with: ->(url) { Url.tidy(url) }
    validates :probe_kind, inclusion: { in: KINDS }

    scope :probeable, -> { where.not(probe_kind: "none") }
    # Each row carries its own interval, so ask SQLite to do the arithmetic
    # rather than loading every probeable to ask it one at a time.
    scope :due, -> {
      probeable.where("last_probed_at IS NULL OR last_probed_at <= datetime('now', '-' || probe_interval || ' seconds')")
    }
  end

  # Runs the probe and records it. Returns true if anything visible changed, so
  # callers can stay quiet when nothing did.
  def probe!
    was = status
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    error = attempt
    elapsed = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round

    reading = error.nil?
    probes.create!(up: reading, latency_ms: (elapsed if reading), error: error, created_at: Time.current)
    update!(status: reading ? :up : :down, latency_ms: (elapsed if reading), last_probed_at: Time.current)

    was != status
  end

  def due?
    probe_kind != "none" &&
      (last_probed_at.nil? || last_probed_at <= Time.current - probe_interval.seconds)
  end

  def uptime_ratio(window = 1.hour)
    recent = probes.where(created_at: window.ago..)
    return nil if recent.empty?
    recent.where(up: true).count.fdiv(recent.count)
  end

  private
    # Returns nil when the thing answered, or a short human reason when it did not.
    def attempt
      case probe_kind
      when "tcp"  then try_tcp
      when "http" then try_http
      when "icmp" then try_icmp
      else "no probe configured"
      end
    rescue => e
      e.message.truncate(120)
    end

    def try_tcp
      return "no address" if address.blank?
      return "no port" if probe_port.blank?

      Socket.tcp(address, probe_port, connect_timeout: TIMEOUT) { |s| s.close }
      nil
    # A refusal is not silence. The host sent back an RST, which means it is
    # switched on and reachable and simply has nothing listening there — so say
    # that, rather than "connection refused", which reads like the network is
    # broken when the port number is the only thing that is.
    rescue Errno::ECONNREFUSED then "port #{probe_port} closed, host answered"
    rescue Errno::EHOSTUNREACH then "host unreachable"
    rescue Errno::ENETUNREACH  then "network unreachable"
    rescue Errno::ETIMEDOUT, IO::TimeoutError then "timed out"
    rescue SocketError then "cannot resolve"
    end

    def try_http
      target = URI.parse(probe_url.presence || http_target.to_s)
      return "no url" if target.host.blank?

      # Homelab services are full of self-signed certificates. Refusing to talk
      # to them would report a working service as down, which is a worse lie
      # than not checking the certificate of a box on your own LAN.
      http = Net::HTTP.new(target.host, target.port)
      http.use_ssl = target.scheme == "https"
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      http.open_timeout = http.read_timeout = TIMEOUT

      response = http.start do |c|
        head = c.head(target.request_uri) rescue nil
        # Plenty of services answer HEAD with 405 but are perfectly alive.
        head && !head.is_a?(Net::HTTPMethodNotAllowed) ? head : c.get(target.request_uri)
      end

      response.is_a?(Net::HTTPServerError) ? "http #{response.code}" : nil
    rescue Errno::ECONNREFUSED then "connection refused"
    rescue Net::OpenTimeout, Net::ReadTimeout then "timed out"
    rescue SocketError then "cannot resolve"
    end

    # Raw ICMP sockets need privileges Uplink should not have, so this borrows
    # the setuid ping already on the system.
    def try_icmp
      return "no address" if address.blank?
      return "bad address" unless address.match?(/\A[a-zA-Z0-9._-]+\z/)

      system("ping", "-c", "1", "-W", TIMEOUT.to_s, address,
        out: File::NULL, err: File::NULL) ? nil : "no reply"
    end
end
