// The browser's half of URL repair, kept deliberately free of imports so the
// test suite can load it directly and check it still agrees with Url in
// app/models/url.rb. Two copies of one rule drift; that is how we notice.
const SCHEME = /^[a-z][a-z0-9+.-]*:\/\//i
const HALF_SCHEME = /^(https?):\/(?!\/)/i

// Undoes damage, and nothing else. Safe to run mid-edit, because it only ever
// removes characters that cannot appear in a URL and puts back a slash the
// scheme is missing — it never adds anything you did not type.
export function repair(value) {
  return String(value).replace(/\s+/g, "").replace(HALF_SCHEME, "$1://")
}

// Repair, plus the assumption that a scheme-less address meant http. That is
// a guess rather than a correction, so it waits until you have left the field.
export function tidy(value) {
  const url = repair(value)
  if (url === "") return ""

  return SCHEME.test(url) ? url : `http://${url.replace(/^\/+/, "")}`
}
