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

    assert_equal 1, broadcasts.size
    assert_match(/turbo-stream action="replace" target="theme-stylesheet"/, broadcasts.last)
    assert_match(/\/theme\.css\?v=\d+/, broadcasts.last, "without a new url the browser serves the old palette from cache")
  end

  test "the layout carries the palette and the font in one replaceable element" do
    get "/"

    assert_select "style#theme-stylesheet", count: 1
    assert_match(/@import url\("\/theme\.css\?v=\d+"\)/, response.body)
    assert_match(/--font:/, response.body)
  end
end
