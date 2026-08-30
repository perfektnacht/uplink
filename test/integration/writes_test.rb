require "test_helper"

# Uplink is reached over plain http on loopback. Rails' production defaults
# assume a TLS-terminating proxy, and when they are left on, request.base_url
# reports https, disagrees with the browser's http Origin, and every single
# form in the app fails CSRF with a 422 that Turbo renders as "Content
# missing". Nothing saves and nothing explains why.
#
# These are the two guards against that ever being invisible again.
class WritesTest < ActionDispatch::IntegrationTest
  setup do
    @forgery = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
  end

  teardown { ActionController::Base.allow_forgery_protection = @forgery }

  test "a rejected write answers with something Turbo can actually show" do
    patch node_path(nodes(:router)),
      params: { node: { name: "Edge" } },
      headers: { "HTTP_ORIGIN" => "https://localhost:3030" }

    assert_response :unprocessable_entity
    assert_select "turbo-frame#inspector", /Not saved/
  end

  # The configuration itself, because the behaviour above only shows up over
  # http from a real browser — curl sends no Origin header and the test
  # environment does not assume SSL, so nothing else here would catch a
  # regression.
  test "production does not assume a reverse proxy that does not exist" do
    production = Rails.root.join("config/environments/production.rb").read

    assert_match(/^\s*config\.assume_ssl = false/, production,
      "assume_ssl makes base_url report https and breaks every form over http")
    assert_match(/^\s*config\.force_ssl = false/, production,
      "force_ssl would redirect loopback http traffic to a port serving no TLS")
  end
end
