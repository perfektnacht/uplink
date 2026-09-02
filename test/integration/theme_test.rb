require "test_helper"

# The desktop-to-browser bridge. If this breaks, Uplink still works but stops
# being an Omarchy app, which is most of the point.
class ThemeTest < ActionDispatch::IntegrationTest
  # Explicit rather than inherited: whether this is in scope otherwise depends
  # on which test file loaded first, which made this pass or fail by seed.
  include ActionCable::TestHelper

  test "the palette Omarchy rendered is served as css" do
    get "/theme.css"

    assert_response :success
    assert_equal "text/css", response.media_type
    assert_match(/--accent:/, response.body)
    assert_no_match(/\{\{/, response.body, "an unrendered placeholder means a theme is missing a colour")
  end

  test "the stylesheet is never cached, because being stale is its only failure mode" do
    get "/theme.css"
    assert_no_match(/max-age=[1-9]/, response.headers["Cache-Control"].to_s)
  end

  test "the theme-set hook can poke us without a session or a token" do
    post "/theme/changed", params: { name: "tokyo-night" }
    assert_response :no_content
  end

  test "a theme change broadcasts a replacement stylesheet with a fresh url" do
    broadcasts = capture_broadcasts("omarchy") { post "/theme/changed" }
    stylesheet = broadcasts.find { |frame| frame.include?("theme-stylesheet") }

    assert stylesheet, "the palette is the whole point of the hook"
    assert_match(/turbo-stream action="replace" target="theme-stylesheet"/, stylesheet)
    assert_match(/\/theme\.css\?v=\d+/, stylesheet, "without a new url the browser serves the old palette from cache")
  end

  # The name in the corner is the only text on the page that says which theme
  # you are looking at, and it used to keep saying the old one until a reload.
  test "a theme change also refreshes the name in the corner" do
    broadcasts = capture_broadcasts("omarchy") { post "/theme/changed" }

    assert broadcasts.any? { |frame| frame.include?(%(target="theme-name")) }
  end

  # Chromium asks for a favicon on every load, and Uplink runs as an Omarchy
  # web app where the icon is the window. It may as well match the desktop.
  test "the window icon is drawn in the desktop's own colours" do
    get icon_path

    assert_response :success
    assert_equal "image/svg+xml", response.media_type
    assert_includes response.body, Omarchy.accent
    assert_includes response.body, Omarchy.background
  end

  test "the page names its icon, so nothing goes looking for favicon.ico" do
    get "/"
    assert_select "link[rel=icon][type=?][href^=?]", "image/svg+xml", "/icon.svg"
  end

  test "the layout carries the palette and the font in one replaceable element" do
    get "/"

    assert_select "style#theme-stylesheet", count: 1
    assert_match(/@import url\("\/theme\.css\?v=\d+"\)/, response.body)
    assert_match(/--font:/, response.body)
  end

  # The one endpoint that skips forgery protection, so what stands in for the
  # token is where the request came from -- and that has to be the socket
  # rather than a header, because a header is something the caller writes.
  test "a request that only claims to be local is refused" do
    post "/theme/changed", headers: { "X-Forwarded-For" => "127.0.0.1" }

    assert_response :forbidden
  end

  test "a forwarded request is refused rather than read past" do
    # Behind a proxy the peer is the proxy, so trusting the socket alone would
    # wave through whatever the proxy fronts for. Uplink is not a thing to put
    # a proxy in front of.
    [ "1.2.3.4", "127.0.0.1, 192.168.1.50" ].each do |forwarded|
      post "/theme/changed", headers: { "X-Forwarded-For" => forwarded }

      assert_response :forbidden, "forwarded as #{forwarded.inspect}"
    end
  end

  test "the hook itself, which sends no such header, still gets through" do
    post "/theme/changed"

    assert_response :no_content
  end

  # The wallpaper is washed across the canvas behind everything at a third
  # opacity, so a stale one tints the whole page. Written into application.css
  # as a bare url() it could not carry a version and was never refetched: a
  # theme switch repainted every colour and left the previous picture behind
  # them until a hard refresh.
  test "the wallpaper is asked for by a url that moves with the desktop" do
    get root_path

    assert_response :success
    assert_match %r{--wallpaper:\s*url\("/theme/wallpaper\?v=\d+"\)}, response.body
  end

  test "the page asks for no unversioned desktop resource at all" do
    get root_path

    assert_no_match %r{url\("/theme/wallpaper"\)}, response.body,
      "an unversioned wallpaper url is one the browser will keep from cache"
  end

  # Nothing to read is not an error, and a fresh clone has nothing to read.
  test "no wallpaper is a background of none rather than a broken url" do
    was = Omarchy.method(:wallpaper)
    Omarchy.define_singleton_method(:wallpaper) { nil }

    get root_path

    assert_response :success
    assert_match(/--wallpaper:\s*none/, response.body)
  ensure
    Omarchy.define_singleton_method(:wallpaper, was)
  end
end
