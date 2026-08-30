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

  test "nothing stays nothing" do
    assert_nil Url.tidy(nil)
    assert_nil Url.tidy("")
    assert_nil Url.tidy("   ")
  end

  test "a protocol-relative address does not end up with four slashes" do
    assert_equal "http://192.168.1.50", Url.tidy("//192.168.1.50")
  end
end
