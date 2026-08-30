require "test_helper"

class GroveIntegrationTest < ActionDispatch::IntegrationTest
  test "the grove renders as one svg document" do
    get grove_path

    assert_response :success
    assert_select "svg#grove-scene", 1
    assert_select "svg .bough", minimum: 1
  end

  # The fixture server is down, so nothing in the default network is leafy.
  test "a node that is answering carries leaves, all of them in one path" do
    nodes(:server).update!(status: "up")

    get grove_path

    assert_select "svg .leaves--live", 1
  end

  # A thousand twigs would be a thousand elements if each carried its own
  # width. They are bucketed by generation instead, so the whole tangle is a
  # handful of paths.
  test "the twigs are batched by generation rather than drawn one by one" do
    get grove_path

    assert_select "svg .twig", maximum: Grove::RAMIFY
  end

  # The grove is something you look at, so there is nothing on it to click.
  test "nothing in the scene is clickable" do
    get grove_path

    assert_select "svg a", 0
  end

  test "the bottom bar moves between the two views and says which one you are on" do
    get root_path
    assert_select ".hud__view--on", text: "canvas"
    assert_select ".hud__view[href=?]", grove_path

    get grove_path
    assert_select ".hud__view--on", text: "grove"
    assert_select ".hud__view[href=?]", root_path
  end

  # The canvas is where you edit; those controls do not follow you into a
  # picture that cannot be edited.
  test "the grove drops the canvas tools but keeps the speedtest" do
    get grove_path

    assert_select "[data-controller=speedtest]", 1
    assert_select "[data-action*=toggleMode]", 0
    assert_select "a[href=?]", new_node_path, 0
  end

  test "the canvas is untouched" do
    get root_path

    assert_response :success
    assert_select "#nodes .node", minimum: 1
    assert_select "svg#grove-scene", 0
  end
end
