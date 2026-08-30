module UplinkHelper
  # The colour that says what a piece of gear is. The six that Uplink seeds are
  # assigned deliberately; anything you invent gets a stable colour from the
  # rest of the theme's palette, so a kind nobody anticipated still looks like
  # it belongs rather than falling back to grey.
  # `host` is deliberately the quiet one. It is the commonest kind on any
  # network, and colouring the default case leaves nothing left over to mark
  # the infrastructure that actually shapes the diagram.
  TINTS = {
    "internet" => "--cyan", "modem" => "--bright-magenta", "router" => "--accent",
    "switch" => "--blue", "host" => "--fg-soft", "appliance" => "--magenta"
  }.freeze

  # Green, red and yellow are deliberately absent: those three mean up, down
  # and degraded, and a kind label wearing one would be competing with the
  # status dot beside it.
  SPARE = %w[ --bright-magenta --bright-cyan --bright-blue --magenta --cyan ].freeze

  def node_tint(kind)
    key = kind.to_s.downcase.strip
    token = TINTS[key] || SPARE[key.sum % SPARE.size]

    # --orange is absent from a few stock themes, and an invented kind might
    # land on any token at all, so everything falls back to the accent.
    "var(#{token}, var(--accent))"
  end

  # Nothing in Uplink is a login, but a panel full of text fields looks enough
  # like one that password managers offer to save it as an identity. These are
  # the opt-outs 1Password, LastPass and Bitwarden each document.
  def unmanaged(options = {})
    { autocomplete: "off",
      data: { "1p-ignore": true, lpignore: true, bwignore: true, "form-type": "other" } }
      .deep_merge(options)
  end

  def dot_title(probeable)
    case probeable.status
    when "up"   then "up#{" · #{probeable.latency_ms}ms" if probeable.latency_ms}"
    when "down" then "down · #{probeable.probes.last&.error}"
    else "not probed"
    end
  end
end
