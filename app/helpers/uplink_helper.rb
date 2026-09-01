module UplinkHelper
  # Nothing in Uplink is a login, but a panel full of text fields looks enough
  # like one that password managers offer to save it as an identity. These are
  # the opt-outs 1Password, LastPass and Bitwarden each document.
  def unmanaged(options = {})
    { autocomplete: "off",
      data: { "1p-ignore": true, lpignore: true, bwignore: true, "form-type": "other" } }
      .deep_merge(options)
  end

  # A URL field: opted out of password managers like the rest, plus the
  # client-side repair so the field shows what will actually be saved.
  def address_field(options = {})
    unmanaged({ inputmode: "url", data: { controller: "url", action: "blur->url#tidy paste->url#paste" } }.deep_merge(options))
  end

  # A wildcard-certificate hostname writes the LAN address in its first label
  # and then carries a certificate hash: Unraid hands out
  # 192-168-1-10.a1b2c3d4…myunraid.net, and nip.io, sslip.io and traefik.me
  # all work the same way. The address is the only part of that worth a row in
  # the roster, and it is the same address every other row is showing.
  DASHED_IP = /\A(\d{1,3}(?:-\d{1,3}){3})\./

  def short_host(host)
    (dashed = host.to_s[DASHED_IP, 1]) ? dashed.tr("-", ".") : host
  end

  def dot_title(probeable)
    case probeable.status
    when "up"   then "up#{" · #{probeable.latency_ms}ms" if probeable.latency_ms}"
    when "down" then "down · #{probeable.probes.last&.error}"
    else "not probed"
    end
  end
end
