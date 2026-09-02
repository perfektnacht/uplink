# Tidies whatever actually arrived in a URL field.
#
# Homelab addresses get typed, pasted, and half-corrected by browser extensions
# that think a URL field is a saved login, and the useful behaviour is to accept
# the intent rather than reject the string. A field that rejects
# "192.168.1.10:8080" because it lacks a scheme is being pedantic about a
# machine you can see from where you are sitting.
module Url
  SCHEME = %r{\A[a-z][a-z0-9+.-]*://}i

  # Schemes a browser runs as code when it follows a link. A service's URL is
  # printed straight into an href, so one of these stored on a card is script
  # waiting for a click -- and `repair` makes it worse before it makes it
  # better, because stripping whitespace turns "java\tscript://" into a clean
  # "javascript://" that a naive filter would have caught and this one does not.
  #
  # Not an allowlist: ssh, smb, vnc and the rest are ordinary things to keep on
  # a homelab dashboard, and refusing them to catch three would be the kind of
  # pedantry this module exists to avoid.
  UNSAFE_SCHEME = %r{\A(?:javascript|data|vbscript):}i

  # A scheme followed by one slash instead of two. Typing "http://" and pasting
  # after it is enough to produce this, with help from a password manager that
  # rewrites the field as you go.
  HALF_SCHEME = %r{\A(https?):/(?!/)}i

  # Undoes damage, and nothing else.
  #
  # Every space goes, not just the ones at the ends: a URL cannot contain a raw
  # space, so one that arrives with a space in the middle — "http: /host",
  # which is what a lost slash looks like on screen — is a mangled URL rather
  # than a URL with a space in it.
  def self.repair(value)
    value.to_s.gsub(/\s+/, "").sub(HALF_SCHEME, '\1://')
  end

  # Repair, plus the assumption that a scheme-less address meant http.
  def self.tidy(value)
    url = repair(value)
    return nil if url.empty?
    return url if url.match?(SCHEME) && !url.match?(UNSAFE_SCHEME)

    # Anything that runs as code falls through to here and comes out inert,
    # which is already what "javascript:alert(1)" did for want of a second
    # slash. The two forms now agree.
    "http://#{url.sub(%r{\A/+}, "")}"
  end
end
