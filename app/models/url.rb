# Tidies whatever actually arrived in a URL field.
#
# Homelab addresses get typed, pasted, and half-corrected by browser extensions
# that think a URL field is a saved login, and the useful behaviour is to accept
# the intent rather than reject the string. A field that rejects
# "192.168.1.10:8080" because it lacks a scheme is being pedantic about a
# machine you can see from where you are sitting.
module Url
  SCHEME = %r{\A[a-z][a-z0-9+.-]*://}i

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
    return url if url.match?(SCHEME)

    "http://#{url.sub(%r{\A/+}, "")}"
  end
end
