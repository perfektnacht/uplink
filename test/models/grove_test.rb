require "test_helper"

class GroveTest < ActiveSupport::TestCase
  # The fixture network is internet → router → switch → server, with the
  # server down and one service inside it.
  test "the trunk is the internet, because that is where the packets enter" do
    assert_equal nodes(:internet), Grove.draw.internet
  end

  test "a network with no internet node still grows, from its busiest one" do
    nodes(:internet).destroy!

    grove = Grove.draw

    assert_nil grove.internet
    assert grove.boughs.any?, "a network without an internet node still has a shape"
  end

  test "an empty network draws nothing rather than raising" do
    clear_canvas

    grove = Grove.draw

    assert_empty grove.boughs
    assert_empty grove.crowns
  end

  # The seeded generator is the whole reason the tree is a diagram and not a
  # kaleidoscope. Two renders of the same rows must be the same picture.
  test "the same network draws the same tree twice" do
    assert_equal Grove.draw.boughs.map { |bough| bough[:body] },
                 Grove.draw.boughs.map { |bough| bough[:body] }
  end

  # A second path back to the switch is a redundant cable, not a second branch.
  test "a redundant cable does not grow a second branch" do
    Link.create!(from_node: nodes(:internet), to_node: nodes(:switch), kind: "ethernet")

    grown = Grove.draw.labels.map { |label| label[:node] }

    assert_equal Node.count, grown.size
    assert_equal grown.uniq, grown, "every node grows exactly once"
  end

  # A ring of switches is a perfectly ordinary thing to have cabled by mistake.
  test "a cycle in the cabling does not send the walk round forever" do
    Link.create!(from_node: nodes(:server), to_node: nodes(:internet), kind: "ethernet")

    assert Grove.draw.boughs.any?
  end

  test "a node that is down drops its crown on the ground and snaps its limb" do
    grove = Grove.draw
    fallen = grove.crowns.select { |crown| crown[:state] == "fallen" }

    assert_equal [ nodes(:server) ], fallen.map { |crown| crown[:node] }
    assert fallen.first[:y] > Grove::GROUND, "a fallen crown lies below the horizon"
    assert grove.boughs.any? { |bough| bough[:splinter].present? }, "the limb tore rather than ended"
  end

  # Uplink probes every node for itself, so a switch that stopped answering
  # tells you nothing about the server behind it — which may well still be
  # answering. Dropping that server out of the tree would be drama at the cost
  # of the truth, so the branch goes to dead wood and the growth continues.
  test "what is behind a dead limb is drawn as it measures, not as its parent" do
    nodes(:server).update!(status: "up")
    nodes(:switch).update!(status: "down")

    grove = Grove.draw
    states = grove.crowns.to_h { |crown| [ crown[:node], crown[:state] ] }

    assert_equal "fallen", states[nodes(:switch)]
    assert_equal "up", states[nodes(:server)], "the server answers, so it keeps its leaves"
  end

  # Nothing depends on a leaf, so a dead one can come off cleanly.
  test "a dead node with nothing behind it snaps off short" do
    stub = Grove.draw.boughs.find { |bough| bough[:splinter].present? }

    assert stub, "the limb to the dead server tore rather than ended"
  end

  # Leaves fall from anything with a dead service in it, including a switch —
  # which has no crown of its own to lose them from.
  test "a dead service is leaves on the floor" do
    nodes(:server).update!(status: "up")
    nodes(:router).services.create!(name: "Admin", url: "http://192.0.2.1",
                                   status: "down", probe_kind: "http")

    grove = Grove.draw

    assert_equal 6, grove.litter.size, "six leaves per dead service"
    assert_equal 2, grove.falling.size, "and a couple still on the way down"
  end

  test "a node with no cable to anything is a raven, not a branch" do
    vps = Node.create!(name: "Hetzner", kind: "vps", status: "up", probe_kind: "none")

    grove = Grove.draw

    assert_equal [ vps ], grove.ravens.map { |raven| raven[:node] }
    assert_equal "perched", grove.ravens.first[:pose]
    assert_not_includes grove.crowns.map { |crown| crown[:node] }, vps
  end

  test "a raven whose host is down is on the ground, hunting, far from the tree" do
    Node.create!(name: "Hetzner", kind: "vps", status: "down", probe_kind: "none")

    raven = Grove.draw.ravens.first

    assert_equal "hunting", raven[:pose]
    assert raven[:y] > Grove::GROUND, "it is on the ground"
    assert (raven[:x] - Grove::BASE_X).abs > 150, "and not under the tree"
  end

  # Whatever shape the network turns out to be, it has to fit in the window.
  test "the tree is scaled to the frame rather than tuned to fit one network" do
    12.times do |i|
      box = Node.create!(name: "Box #{i}", kind: "server", status: "up", probe_kind: "none")
      Link.create!(from_node: nodes(:switch), to_node: box, kind: "ethernet")
    end

    grove = Grove.draw
    top   = grove.crowns.map { |crown| crown[:y] - crown[:r] }.min

    assert top > 0, "the canopy stays inside the sky"
    assert grove.crowns.all? { |crown| crown[:x].between?(0, Grove::W) }, "and inside the frame"
  end

  test "the internet being down is an eclipse" do
    assert_not Grove.draw.eclipsed?

    nodes(:internet).update!(status: "down")

    assert Grove.draw.eclipsed?
  end

  test "the orb grows with the download, and is there before the first reading" do
    dark = Grove.draw.orb[:r]
    Speedtest.create!(down_mbps: 900, up_mbps: 40, latency_ms: 8)

    assert Grove.draw.orb[:r] > dark
  end

  test "the stone lists every service, grouped by what runs it" do
    assert_equal [ [ nodes(:server), [ services(:plex) ] ] ], Grove.draw.rosters
  end

  private
    def clear_canvas
      Link.delete_all
      Service.delete_all
      Node.delete_all
    end
end
