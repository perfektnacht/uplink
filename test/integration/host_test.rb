require "test_helper"

# Binding to loopback keeps other machines out. It does not keep other websites
# out: a page can point its own domain at 127.0.0.1 with a one-second TTL and
# fetch itself, and the same-origin policy calls the answer that page's own. So
# the page reads the whole canvas -- every hostname, address and service on the
# LAN -- plus a CSRF token good for writing back.
#
# Uplink has no login precisely because it trusts the loopback boundary, which
# is exactly why the boundary has to be real.
class HostTest < ActionDispatch::IntegrationTest
  test "the loopback names the desktop actually opens Uplink by are answered" do
    %w[ localhost 127.0.0.1 ].each do |name|
      host! name
      get root_path

      assert_response :success, "#{name} is how Uplink is opened"
    end
  end

  test "a hostname somebody else pointed at loopback is refused" do
    %w[ evil.example.com uplink.attacker.test 127.0.0.1.nip.io ].each do |name|
      host! name
      get root_path

      assert_response :forbidden, "#{name} was allowed to read the canvas"
    end
  end

  test "the grove and the theme hook are behind the same guard" do
    host! "evil.example.com"

    get grove_path
    assert_response :forbidden

    post "/theme/changed"
    assert_response :forbidden
  end
end
