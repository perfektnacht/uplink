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

  def self.tidy(value)
    url = value.to_s.strip
    return nil if url.empty?

    url = url.sub(HALF_SCHEME, '\1://')
    return url if url.match?(SCHEME)

    "http://#{url.delete_prefix("//")}"
  end
end
