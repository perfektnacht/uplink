require "test_helper"

class CanvasTest < ActionDispatch::IntegrationTest
  test "the canvas draws every node, service, and cable" do
    get "/"

    assert_response :success
    assert_select ".node", Node.count
    assert_select ".service", Service.count
    assert_select "path.cable", minimum: Link.where.not(kind: "logical").count
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

  # A cable you cannot select is a cable you cannot fix. Every path carries an
  # invisible wide stroke whose only job is to be clickable.
  test "every cable is selectable and opens in the inspector" do
    get "/"
    assert_select "path.cable__hit", Link.where.not(kind: "logical").count

    get edit_link_path(links(:uplink))
    assert_select "turbo-frame#inspector form"
    assert_select "turbo-frame#inspector select[name=?]", "link[kind]"
  end

  # A logical link is many-to-one — every machine can point at one Pi-hole — so
  # it is drawn on the card that depends on it rather than as another cable.
  test "a logical link is a chip on the card, not a cable" do
    get "/"

    assert_select "##{ActionView::RecordIdentifier.dom_id(nodes(:server))} .uses__link", 1
    assert_select "##{ActionView::RecordIdentifier.dom_id(nodes(:server))} .uses__link", text: /DNS/
    assert_select "path##{ActionView::RecordIdentifier.dom_id(links(:dns))}", count: 0
  end

  test "a chip names the far end when it has no label of its own" do
    links(:dns).update!(label: nil)
    get "/"

    assert_select ".uses__link", text: /Router/
  end

  test "a chip opens its link in the inspector" do
    get edit_link_path(links(:dns))

    assert_select "turbo-frame#inspector input[name=?]", "link[label]"
    assert_select "turbo-frame#inspector select[name=?]", "link[kind]"
  end

  test "a cable can be re-kinded without being redrawn" do
    patch link_path(links(:uplink)), params: { link: { kind: "fiber" } }

    assert_select "turbo-frame#inspector"
    assert_equal "fiber", links(:uplink).reload.kind
  end

  test "a cable can be deleted from the inspector" do
    assert_difference "Link.count", -1 do
      delete link_path(links(:uplink))
    end
    assert_select "turbo-frame#inspector"
  end

  test "a cable can be moved to different endpoints" do
    patch link_path(links(:uplink)), params: { link: { to_node_id: nodes(:server).id } }

    assert_equal nodes(:server), links(:uplink).reload.to_node
  end

  # Nested forms are invalid HTML: the parser drops the inner <form> and its
  # hidden _method input joins the outer one, where it competes with the method
  # already declared there.
  test "no form in the inspector is nested inside another" do
    [ edit_node_path(nodes(:router)), edit_link_path(links(:uplink)) ].each do |path|
      get path
      assert_select "form form", count: 0, message: "#{path} nests a form inside a form"
    end
  end

  test "a speedtest is queued rather than run in the request" do
    assert_enqueued_with job: SpeedtestJob do
      post speedtests_path
    end
    assert_response :accepted
  end
end
