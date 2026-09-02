require "test_helper"
require "tempfile"

# These read the real desktop, because the whole point of the module is that
# the desktop is the source of truth. If Omarchy moves these paths, this fails
# here rather than silently serving a stale palette.
class OmarchyTest < ActiveSupport::TestCase
  test "the theme directory Omarchy stages is where we look" do
    assert_equal Pathname.new(Dir.home).join(".local/state/omarchy/current"), Omarchy::STATE
  end

  test "the rendered stylesheet is inside the current theme" do
    assert_equal "uplink.css", Omarchy.stylesheet.basename.to_s
    assert_equal "theme", Omarchy.stylesheet.dirname.basename.to_s
  end

  test "the font name is safe to drop into a style block" do
    assert_match(/\A[A-Za-z0-9 _-]+\z/, Omarchy.font)
  end

  # These two need a desktop to read, so they say so rather than failing on a
  # machine that has not got one. Everything above is path arithmetic and holds
  # anywhere; everything below is the answer when there is nothing to read,
  # which is the case CI actually exercises.
  test "the theme name is whatever omarchy last wrote" do
    skip "no Omarchy theme staged" unless Omarchy::STATE.join("theme.name").exist?

    assert_equal Omarchy::STATE.join("theme.name").read.strip, Omarchy.theme_name
  end

  test "the revision changes when the stylesheet does" do
    skip "no Omarchy theme staged" unless Omarchy.stylesheet.exist?

    assert_kind_of Integer, Omarchy.revision
    assert_operator Omarchy.revision, :>, 0
  end

  # Uplink has to stay legible on a machine where bin/uplink-install has not
  # run, because that is what a fresh clone is. Nothing here may raise.
  test "a missing theme is answered rather than raised" do
    sheet, link = Omarchy.method(:stylesheet), Omarchy.method(:background_link)
    Omarchy.define_singleton_method(:stylesheet) { Pathname.new("/nonexistent/uplink.css") }
    Omarchy.define_singleton_method(:background_link) { Pathname.new("/nonexistent/background") }

    assert_equal 0, Omarchy.revision
    assert_equal "#7aa2f7", Omarchy.accent
    assert_equal "#16161e", Omarchy.background
  ensure
    Omarchy.define_singleton_method(:stylesheet, sheet)
    Omarchy.define_singleton_method(:background_link, link)
  end

  # The wallpaper is fetched by URL, so it has to move the revision on its own:
  # cycling backgrounds inside a theme rewrites the symlink without touching
  # uplink.css, and a browser asked for a URL it has already seen keeps the
  # picture it already has.
  test "a new wallpaper moves the revision even when the palette has not" do
    sheet, link = Omarchy.method(:stylesheet), Omarchy.method(:background_link)
    Omarchy.define_singleton_method(:stylesheet) { Pathname.new("/nonexistent/uplink.css") }

    Tempfile.create("background") do |file|
      Omarchy.define_singleton_method(:background_link) { Pathname.new(file.path) }
      before = Omarchy.revision

      File.utime(Time.now + 60, Time.now + 60, file.path)

      assert_operator Omarchy.revision, :>, before
    end
  ensure
    Omarchy.define_singleton_method(:stylesheet, sheet)
    Omarchy.define_singleton_method(:background_link, link)
  end

  test "a font name is always something a style block can hold" do
    assert_match(/\A[A-Za-z0-9 _-]+\z/, Omarchy.font)
    assert Omarchy.font.present?
  end
end
