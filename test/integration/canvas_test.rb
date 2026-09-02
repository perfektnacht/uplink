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

  # An Unraid box hands out a hostname that spells its own address and then
  # carries forty characters of certificate hash. The roster shows the address.
  test "a wildcard-certificate hostname is shown as the address it spells" do
    services(:plex).update!(
      url: "https://192-0-2-10.a1b2c3d4e5f60718293a4b5c6d7e8f9012345678.myunraid.net/")
    get edit_node_path(nodes(:server))

    assert_select ".roster__name", text: "Plex"
    assert_select ".roster__host", text: "192.0.2.10"
  end

  # Kinds are all one colour, from the stylesheet. A card carries no colour of
  # its own beyond position and width: the only meaningful colour on it is the
  # dot, and a palette of kinds was competing with it.
  test "a card is styled with geometry and nothing else" do
    nodes(:router).update!(kind: "smart home hub")
    get "/"

    assert_select "##{ActionView::RecordIdentifier.dom_id(nodes(:router))}" do |card|
      assert_no_match(/color|tint/, card.first["style"])
    end
    assert_select ".node__kind", text: "smart home hub"
  end

  # A datalist opens over the corner of the input where a password manager puts
  # its own icon, and the two fight for the same few pixels.
  test "the kind field suggests with chips, not a native dropdown" do
    get edit_node_path(nodes(:router))

    assert_select "input[name=?]", "node[kind]"
    assert_select "input[name=?][list]", "node[kind]", count: 0
    assert_select "datalist", count: 0
    assert_select ".chip[data-suggest-value-param]", Node::KINDS.size
  end

  # The result belongs to the thing it measures, not to a strip at the bottom
  # of the window.
  test "the last speedtest is shown inside the Internet card" do
    Speedtest.create!(down_mbps: 133.4, up_mbps: 11.1, latency_ms: 69, created_at: Time.current)
    internet = Node.create!(name: "Internet", kind: "internet", probe_kind: "none", x: 0, y: 0)
    get "/"

    assert_select "##{ActionView::RecordIdentifier.dom_id(internet)} #speedtest", 1
    assert_select "##{ActionView::RecordIdentifier.dom_id(internet)} #speedtest", /133.4/
    assert_select ".hud #speedtest", count: 0
  end

  test "a card with no speedtest yet says so rather than showing nothing" do
    internet = Node.create!(name: "Internet", kind: "internet", probe_kind: "none", x: 0, y: 0)
    get "/"

    assert_select "##{ActionView::RecordIdentifier.dom_id(internet)} .speed__idle"
  end

  # A panel of text fields looks enough like a login that password managers
  # offer to save it as an identity.
  test "no inspector field invites a password manager" do
    get edit_node_path(nodes(:router))

    inputs = css_select("#inspector input:not([type=hidden]):not([type=submit])")
    assert_predicate inputs, :any?
    inputs.each do |input|
      assert_equal "true", input["data-1p-ignore"], "#{input["name"]} is not opted out of 1Password"
      assert_equal "off", input["autocomplete"], "#{input["name"]} still autocompletes"
    end
  end

  # Privacy mode has to have something to grab hold of: every address on the
  # canvas is marked, so a CSS class can redact all of them at once.
  test "every address on a card is marked for redaction" do
    get "/"

    addressed = Node.where.not(address: [ nil, "" ]).count
    assert_operator addressed, :>, 0
    assert_select ".node__addr[data-private]", addressed
  end

  test "the speedtest trigger is in the toolbar, its reading is on the card" do
    Speedtest.create!(down_mbps: 133.4, up_mbps: 11.1, latency_ms: 69, created_at: Time.current)
    Node.create!(name: "Internet", kind: "internet", probe_kind: "none", x: 0, y: 0)
    get "/"

    assert_select ".hud button[data-speedtest-url-value]", 1
    assert_select ".node button[data-speedtest-url-value]", 0
    assert_select ".node #speedtest", /133.4/
  end

  # The service edit form existed from the start and nothing ever linked to it,
  # so a service could be created and never changed again.
  test "a node's form lists its services and links each one for editing" do
    get edit_node_path(nodes(:server))

    assert_select ".roster__item", nodes(:server).services.count
    assert_select ".roster__item[href=?]", edit_service_path(services(:plex))
    assert_select "a[href=?]", new_node_service_path(nodes(:server))
  end

  test "a node with no services says so rather than showing an empty list" do
    get edit_node_path(nodes(:switch))

    assert_select ".roster__list", count: 0
    assert_select ".roster", /Nothing on this one yet/
  end

  test "a service form links back to the machine it runs on" do
    get edit_service_path(services(:plex))

    assert_select ".form__back[href=?]", edit_node_path(nodes(:server))
  end

  test "every service on the canvas can be opened for editing" do
    get "/"

    assert_select ".service__edit", Service.count
    assert_select ".service__edit[href=?]", edit_service_path(services(:plex))
  end

  test "a speedtest is queued rather than run in the request" do
    assert_enqueued_with job: SpeedtestJob do
      post speedtests_path
    end
    assert_response :accepted
  end

  # A new card used to be worked out and then thrown away: nothing carried the
  # position to the form, so every one of them was created at 0,0 -- the corner
  # of a 4000x3000 sheet, and off screen wherever you happened to be looking.
  test "a new card is created where it was placed, not at the origin" do
    get new_node_path, params: { in: "2400,1500,900,700" }

    assert_response :success
    assert_select "input[name=?][value=?]", "node[x]", "2400"
    assert_select "input[name=?][value=?]", "node[y]", "1500"

    assert_difference -> { Node.count } do
      post nodes_path, params: { node: { name: "Placed", kind: "host", x: 2400, y: 1500, width: 240 } }
    end

    assert_equal [ 2400, 1500 ], Node.order(:id).last.slice(:x, :y).values
  end

  test "the card lands inside the part of the sheet the browser can see" do
    box = { x: 2400, y: 1500, width: 900, height: 700 }

    get new_node_path, params: { in: box.values_at(:x, :y, :width, :height).join(",") }
    x = css_select("input[name='node[x]']").first["value"].to_i
    y = css_select("input[name='node[y]']").first["value"].to_i

    assert_operator x, :>=, box[:x]
    assert_operator y, :>=, box[:y]
    assert_operator x + 240, :<=, box[:x] + box[:width], "the card hangs off the right"
    assert_operator y + Node::ASSUMED_HEIGHT, :<=, box[:y] + box[:height], "the card hangs off the bottom"
  end

  # No javascript, or the form reached some other way. It must still work.
  test "without a rectangle it falls back to walking down the left edge" do
    get new_node_path

    assert_select "input[name=?][value=?]", "node[x]", "120"
  end

  test "a rectangle that is nonsense is ignored rather than obeyed" do
    [ "", "1,2", "a,b,c,d", "10,10,0,0", "10,10,-500,-500" ].each do |junk|
      get new_node_path, params: { in: junk }

      assert_response :success, "in=#{junk.inspect}"
      assert_select "input[name=?][value=?]", "node[x]", "120"
    end
  end

  # Dragging saves a position through its own request, so an edit form carrying
  # one would snap the card back to wherever it was when the inspector opened.
  test "the edit form carries no position at all" do
    get edit_node_path(nodes(:router))

    assert_select "input[name=?]", "node[x]", 0
    assert_select "input[name=?]", "node[y]", 0
  end
end
