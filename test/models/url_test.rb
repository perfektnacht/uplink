require "test_helper"

class UrlTest < ActiveSupport::TestCase
  # The one that started this: typing "http://" and pasting after it can arrive
  # with a single slash, courtesy of a password manager rewriting the field.
  test "a scheme that lost a slash gets it back" do
    assert_equal "http://192.168.1.30", Url.tidy("http:/192.168.1.30")
    assert_equal "https://192.168.1.30/admin", Url.tidy("https:/192.168.1.30/admin")
  end

  test "an address with no scheme is assumed to be http" do
    assert_equal "http://192.168.1.10", Url.tidy("192.168.1.10")
    assert_equal "http://192.168.1.10:8080", Url.tidy("192.168.1.10:8080")
    assert_equal "http://tower.local/admin", Url.tidy("tower.local/admin")
  end

  test "a URL that is already fine is left exactly alone" do
    [ "http://192.168.1.1", "https://host/health", "http://host:8080/a/b?c=d" ].each do |url|
      assert_equal url, Url.tidy(url)
    end
  end

  test "a real scheme is never mistaken for a missing one" do
    assert_equal "https://example.com", Url.tidy("https://example.com")
    assert_equal "ftp://host/file", Url.tidy("ftp://host/file")
  end

  test "surrounding whitespace does not survive a paste" do
    assert_equal "http://192.168.1.50", Url.tidy("  http://192.168.1.50\n")
  end

  # What a lost slash actually looks like on screen. A URL cannot hold a raw
  # space, so one in the middle is damage rather than content.
  test "a space in the middle is damage, not content" do
    assert_equal "http://192.168.1.20", Url.tidy("http: /192.168.1.20")
    assert_equal "http://192.168.1.20", Url.tidy("http:/ /192.168.1.20")
    assert_equal "http://192.168.1.20", Url.tidy("http :// 192.168.1.20")
  end

  test "nothing stays nothing" do
    assert_nil Url.tidy(nil)
    assert_nil Url.tidy("")
    assert_nil Url.tidy("   ")
  end

  test "a protocol-relative address does not end up with four slashes" do
    assert_equal "http://192.168.1.50", Url.tidy("//192.168.1.50")
  end

  # The same rule exists twice: here, and in app/javascript/urls.js so the
  # field can show what it is about to save. Two copies of a rule drift, so
  # this loads the browser's copy and insists they still agree. Skipped where
  # node is absent — Uplink needs it for nothing else, and this is a check,
  # not a build step.
  CASES = [
    "http:/192.168.1.30", "192.168.1.10:8080", "http: /192.168.1.20",
    "  https://a/b  ", "//192.168.1.50", "ftp://h/f", "https://example.com",
    "tower.local/admin", "", "   ",
    # Both copies have to defuse these identically, or the field shows one
    # thing and the server stores another.
    "javascript://%0aalert(1)", "java\tscript://%0aalert(1)",
    "JaVaScRiPt://x", "data://text/html,x", "vbscript://x"
  ].freeze

  # A service's URL is printed straight into an href, so a scheme the browser
  # runs as code is script waiting for a click. `repair` strips whitespace
  # before this is decided, which is what makes the tab in "java\tscript://"
  # worth a test of its own: it arrives looking harmless and is normalised into
  # the real thing on the way past.
  test "a scheme the browser would run as code comes out inert" do
    [ "javascript://%0aalert(document.domain)",
      "java\tscript://%0aalert(1)",
      "JaVaScRiPt://%0aalert(1)",
      "java script://%0aalert(1)",
      "data://text/html,<script>alert(1)</script>",
      "vbscript://x" ].each do |payload|
      tidied = Url.tidy(payload)

      assert_match %r{\Ahttp://}, tidied, "#{payload.inspect} kept a scheme that runs"
      assert_no_match(/\A(?:javascript|data|vbscript):/i, tidied)
    end
  end

  # And the ones a homelab actually uses are still ordinary URLs.
  test "the schemes a homelab keeps on a dashboard are left alone" do
    %w[ ssh://box.local smb://nas/share vnc://192.168.1.30:5900 ftp://h/f ].each do |url|
      assert_equal url, Url.tidy(url)
    end
  end

  # Repair runs mid-edit, so it must never add anything you did not type.
  test "repair only ever undoes damage" do
    assert_equal "http://192.168.1.30", Url.repair("http:/192.168.1.30")
    assert_equal "http://192.168.1.20", Url.repair("http: /192.168.1.20")
    assert_equal "192.168.1.10", Url.repair("192.168.1.10"), "repair must not invent a scheme"
    assert_equal "", Url.repair("")
  end

  test "the browser repairs a url exactly as the server does" do
    skip "node not available" unless system("node --version", out: File::NULL, err: File::NULL)

    module_path = Rails.root.join("app/javascript/urls.js")
    program = <<~JS
      import { repair, tidy } from "#{module_path}"
      const cases = #{CASES.to_json}
      console.log(JSON.stringify({ tidy: cases.map(tidy), repair: cases.map(repair) }))
    JS

    output = IO.popen([ "node", "--input-type=module", "-" ], "r+") do |node|
      node.write(program)
      node.close_write
      node.read
    end

    browser = JSON.parse(output)
    assert_equal CASES.map { |value| Url.tidy(value).to_s }, browser["tidy"]
    assert_equal CASES.map { |value| Url.repair(value).to_s }, browser["repair"]
  end
end
