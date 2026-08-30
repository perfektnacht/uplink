module UplinkHelper
  # Nerd Font glyphs, because Omarchy already guarantees one is installed and
  # the theme template hands us its name. No icon library, no sprite sheet,
  # no network request.
  GLYPHS = {
    "internet"  => "\u{f0a80}",  # cloud
    "modem"     => "\u{f06a5}",  # signal tower
    "router"    => "\u{f0a1c}",  # router
    "switch"    => "\u{f0200}",  # lan-connect
    "host"      => "\u{f0322}",  # server
    "appliance" => "\u{f02da}"   # chip
  }.freeze

  def node_glyph(kind) = GLYPHS.fetch(kind, GLYPHS["host"])

  def dot_title(probeable)
    case probeable.status
    when "up"   then "up#{" · #{probeable.latency_ms}ms" if probeable.latency_ms}"
    when "down" then "down · #{probeable.probes.last&.error}"
    else "not probed"
    end
  end
end
