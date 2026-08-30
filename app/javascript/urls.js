// The browser's half of URL repair, kept deliberately free of imports so the
// test suite can load it directly and check it still agrees with Url.tidy in
// app/models/url.rb. Two copies of one rule drift; this is how we notice.
const SCHEME = /^[a-z][a-z0-9+.-]*:\/\//i
const HALF_SCHEME = /^(https?):\/(?!\/)/i

export function tidy(value) {
  // Every space, not just the ends. A URL cannot contain a raw space, so one
  // in the middle is damage rather than content.
  const url = String(value).replace(/\s+/g, "")
  if (url === "") return ""

  const repaired = url.replace(HALF_SCHEME, "$1://")
  return SCHEME.test(repaired) ? repaired : `http://${repaired.replace(/^\/+/, "")}`
}
