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
end
