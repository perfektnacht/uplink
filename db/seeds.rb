# Seeds from the machine this is running on, not from an imagined network.
# The gateway comes from the routing table; the services come from the
# dashboard plugin's own list if you have one. Everything here is a starting
# point to drag around, not a fixture to preserve.

def gateway
  `ip route`.lines.grep(/^default via/).first.to_s[/via (\S+)/, 1]
end

def dashboard_services
  path = Pathname.new(Dir.home).join(".config", "omarchy", "dashboard", "services.json")
  path.exist? ? JSON.parse(path.read) : []
rescue JSON::ParserError
  []
end

ApplicationRecord.transaction do
  next if Node.any?

  internet = Node.create!(name: "Internet", kind: "internet", x: 480, y: 40, width: 280,
    probe_kind: "http", probe_url: "https://1.1.1.1", probe_interval: 120)

  modem = Node.create!(name: "Modem", kind: "modem", x: 480, y: 200,
    address: "192.168.100.1", probe_kind: "icmp", probe_interval: 300,
    notes: "Most modems only answer on their own subnet. Adjust or set probe to none.")

  router = Node.create!(name: "Router", kind: "router", x: 480, y: 360,
    address: gateway || "192.168.1.1", probe_kind: "icmp")

  Link.create!(from_node: internet, to_node: modem, kind: "coax")
  Link.create!(from_node: modem, to_node: router, kind: "ethernet")

  # Pi-hole is drawn off to the side and linked logically: DNS is a
  # relationship, not a cable. It is a `host` because it almost always is one —
  # a Raspberry Pi or a small box you administer. `appliance` is for the gear
  # that does one job and that you never log into: an access point, a printer,
  # a managed PDU.
  pihole = Node.create!(name: "Pi-hole", kind: "host", x: 840, y: 360, width: 220,
    address: "192.168.1.2", probe_kind: "tcp", probe_port: 80,
    notes: "DNS. Point this at your Pi-hole, or delete it.")
  Link.create!(from_node: router, to_node: pihole, kind: "logical")

  switch = Node.create!(name: "Switch", kind: "switch", x: 480, y: 520, width: 280,
    probe_kind: "none", notes: "Unmanaged switches answer nothing. That is fine.")
  Link.create!(from_node: router, to_node: switch, kind: "ethernet")

  # Anything the dashboard plugin already knows about is very likely on one
  # box; group it under that host rather than scattering it.
  services = dashboard_services
  host_address = services.filter_map { |s| URI.parse(s["url"]).host rescue nil }
    .grep(/\A\d+\.\d+\.\d+\.\d+\z/).tally.max_by(&:last)&.first

  if services.any?
    host = Node.create!(name: "Server", kind: "host", x: 300, y: 700, width: 460,
      address: host_address, probe_kind: (host_address ? "icmp" : "none"))
    Link.create!(from_node: switch, to_node: host, kind: "ethernet")

    services.each_with_index do |service, index|
      host.services.create!(name: service["name"], url: service["url"],
        icon: service["icon"], position: index, probe_kind: "http")
    end
  end

  this = Node.create!(name: "This machine", kind: "host", x: 840, y: 520, width: 220,
    address: "127.0.0.1", probe_kind: "tcp", probe_port: 3030)
  Link.create!(from_node: switch, to_node: this, kind: "ethernet")
end

puts "Seeded #{Node.count} nodes, #{Link.count} links, #{Service.count} services."
