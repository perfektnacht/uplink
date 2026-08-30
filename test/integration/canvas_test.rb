require "test_helper"

class CanvasTest < ActionDispatch::IntegrationTest
  test "the canvas draws every node, service, and cable" do
    get "/"

    assert_response :success
    assert_select ".node", Node.count
    assert_select ".service", Service.count
    assert_select "path.cable", minimum: Link.count
  end

  # What a drag lands on: a body containing nothing but coordinates.
  test "a drag saves a position and says nothing else" do
    patch node_path(nodes(:router)), params: { node: { x: 320, y: 88 } }, as: :json

    assert_response :no_content
    assert_equal [ 320, 88 ], nodes(:router).reload.then { |n| [ n.x, n.y ] }
  end

  test "a drag cannot smuggle in other attributes" do
    patch node_path(nodes(:router)), params: { node: { x: 8, status: "up", id: 999 } }, as: :json

    assert_response :no_content
    assert_equal "up", nodes(:router).reload.status
    assert_not_equal 999, nodes(:router).id
  end

  test "wiring two nodes together creates a cable" do
    assert_difference "Link.count" do
      post links_path, params: { link: { from_node_id: nodes(:internet).id, to_node_id: nodes(:server).id } }, as: :json
    end
    assert_response :created
  end

  test "wiring a node to itself is refused rather than raising" do
    assert_no_difference "Link.count" do
      post links_path, params: { link: { from_node_id: nodes(:router).id, to_node_id: nodes(:router).id } }, as: :json
    end
    assert_response :unprocessable_entity
  end

  # A form inside a turbo-frame submits as a frame navigation, so every reply
  # to one has to carry a matching frame. A turbo-stream here would leave Turbo
  # with nothing to swap and it would print "Content missing" at the user.
  test "the inspector opens as a turbo frame and closes by emptying itself" do
    get edit_node_path(nodes(:router))
    assert_select "turbo-frame#inspector form"

    patch node_path(nodes(:router)), params: { node: { name: "Edge" } }
    assert_select "turbo-frame#inspector", count: 1
    assert_select "turbo-frame#inspector form", count: 0
    assert_equal "Edge", nodes(:router).reload.name
  end

  test "every reply the inspector can receive carries a frame" do
    get new_node_path
    assert_select "turbo-frame#inspector"

    # Saved.
    patch node_path(nodes(:router)), params: { node: { name: "Edge" } }
    assert_select "turbo-frame#inspector"

    # Rejected by validation.
    patch node_path(nodes(:router)), params: { node: { name: "" } }
    assert_response :unprocessable_entity
    assert_select "turbo-frame#inspector form"

    # Deleted.
    delete node_path(nodes(:router))
    assert_select "turbo-frame#inspector"
  end

  test "deleting a node takes its services and cables with it" do
    assert_difference [ "Node.count", "Service.count" ], -1 do
      delete node_path(nodes(:server))
    end
    assert_equal 0, Link.where(to_node_id: nodes(:server).id).count
  end

  test "a speedtest is queued rather than run in the request" do
    assert_enqueued_with job: SpeedtestJob do
      post speedtests_path
    end
    assert_response :accepted
  end
end
