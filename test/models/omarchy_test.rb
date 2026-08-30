require "test_helper"

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

  test "the theme name is whatever omarchy last wrote" do
    assert_equal Omarchy::STATE.join("theme.name").read.strip, Omarchy.theme_name
  end

  test "the revision changes when the stylesheet does" do
    assert_kind_of Integer, Omarchy.revision
    assert_operator Omarchy.revision, :>, 0, "run bin/omarchy-install first"
  end
end
