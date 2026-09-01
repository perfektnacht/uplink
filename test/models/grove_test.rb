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

    # Above the ground line only: a node that others depend on is named twice
    # over, once on its crown and once on the root that reaches for it.
    grown = Grove.draw.labels.reject { |label| label[:buried] }.map { |label| label[:node] }

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
    assert (raven[:x] - Grove.draw.trunk_x).abs > 150, "and not under the tree"
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

  # ── the root plate ──────────────────────────────────────────────────────
  #
  # The fixtures already lean on something: links(:dns) is the server asking
  # the router for DNS, logical, labelled.

  test "a dependency with no cable to carry it is a root, named for what it carries" do
    grove = Grove.draw

    assert grove.rootwood.any?, "the plate is drawn"
    assert_equal [ "Router · DNS" ],
                 grove.labels.select { |label| label[:buried] }.map { |label| label[:text] }
  end

  test "a root is named for the link's own label, not for the node twice over" do
    links(:dns).update!(label: nil)

    assert_equal [ "Router" ],
                 Grove.draw.labels.select { |label| label[:buried] }.map { |label| label[:text] }
  end

  test "the thicker root is the one more of the network leans on" do
    pi = Node.create!(name: "Pi-hole", kind: "raspberry pi", status: "up")
    Link.create!(from_node: nodes(:switch),   to_node: pi, kind: "ethernet")
    Link.create!(from_node: nodes(:router),   to_node: pi, kind: "logical", label: "DNS")
    Link.create!(from_node: nodes(:internet), to_node: pi, kind: "logical", label: "DNS")

    plate = Grove.draw

    assert_equal [ "Pi-hole · DNS", "Router · DNS" ],
                 plate.labels.select { |label| label[:buried] }.map { |label| label[:text] }.sort

    # The joint is where a root ends, and its radius is how thick it ended.
    fat = plate.rootwood.select { |root| root[:node] }
               .to_h { |root| [ root[:node].name, root[:joint][2] ] }

    assert fat["Pi-hole"] > fat["Router"],
      "two things leaning on the Pi-hole outgrow one leaning on the router"
  end

  test "a network with no dependencies still stands on a full plate" do
    links(:dns).destroy!

    grove = Grove.draw

    assert_equal 9, grove.rootwood.size
    assert_empty grove.labels.select { |label| label[:buried] }
    assert grove.twigs[:root].any?, "and the plate still has hair on it"
  end

  # Roots are drawn from their own seeds rather than one running sequence, so a
  # dependency appearing cannot reshuffle the roots either side of it.
  test "a new dependency does not redraw the roots that were already there" do
    before = Grove.draw.rootwood.map { |root| root[:body] }

    ntp = Node.create!(name: "Clock", kind: "appliance", status: "up")
    Link.create!(from_node: nodes(:switch), to_node: ntp, kind: "logical", label: "NTP")

    after = Grove.draw.rootwood.map { |root| root[:body] }

    assert_equal 1, before.zip(after).count { |was, is| was != is },
      "one slot is claimed and the other eight are the roots they always were"
  end

  test "a dependency that is down is rot rather than shadow" do
    assert_not Grove.draw.rootwood.any? { |root| root[:dead] }

    nodes(:router).update!(status: "down")

    assert Grove.draw.rootwood.any? { |root| root[:dead] },
      "the root of a provider that is not answering has stopped"
  end

  # A root reaching for the trunk it grew out of says nothing.
  test "the internet never grows a root" do
    links(:dns).update!(to_node: nodes(:internet))

    assert_empty Grove.draw.labels.select { |label| label[:buried] }
  end

  # ── offerings ───────────────────────────────────────────────────────────
  #
  # What tells you there is anything here to point at, without pointing at it.

  test "everything you can name is marked by exactly one thing" do
    vps = Node.create!(name: "Hetzner", kind: "vps", status: "up")

    Grove.draw.labels.each do |label|
      markers = [ label[:offering], label[:raven] ].compact

      assert_equal 1, markers.size,
        "#{label[:node].name} has #{markers.size} markers and should have one"
    end

    assert_equal [ vps ], Grove.draw.ravens.map { |raven| raven[:node] }
  end

  # The bird is already the most conspicuous thing in the picture and it
  # already marks exactly one node.
  test "a raven wears no offering, because it is one" do
    Node.create!(name: "Hetzner", kind: "vps", status: "up")

    grove = Grove.draw
    perched = grove.labels.find { |label| label[:raven] }

    assert_nil perched[:offering]
    assert_equal grove.labels.count { |label| label[:offering] }, grove.offerings.size
  end

  test "a node that is down has dropped its offering" do
    fallen = Grove.draw.offerings.find { |offering| offering[:node] == nodes(:server) }

    assert_equal "fallen", fallen[:state]
    assert fallen[:y] >= Grove::GROUND, "it came down, so it is on the ground"
    assert_equal 0, fallen[:cord], "and there is nothing left holding it up"
  end

  test "a dependency's offering is in the ground with its root" do
    buried = Grove.draw.offerings.select { |offering| offering[:state] == "buried" }

    assert_equal [ nodes(:router) ], buried.map { |offering| offering[:node] }
    assert buried.first[:y] > Grove::GROUND
  end

  # A mark shared with the next node is a mark you cannot learn one node by.
  test "every offering wears its own bind-rune, and the same one twice running" do
    marks = Grove.draw.offerings.map { |offering| offering[:marks] }

    assert marks.size > 3
    assert_equal marks.uniq, marks
    assert_equal marks, Grove.draw.offerings.map { |offering| offering[:marks] }
  end

  # Runes are a stave and diagonals off it. A horizontal stroke is the one
  # thing runic writing has none of — cut that way it splits the wood.
  test "a bind-rune is a stave with arms, and none of them level" do
    rune = Grove.draw.offerings.first[:marks]
    legs = rune.scan(/[ML](-?[\d.]+) (-?[\d.]+)/).map { |x, y| [ x.to_f, y.to_f ] }

    assert legs.size >= 4, "a stave and at least two arms"
    assert legs.each_cons(2).none? { |(_, y1), (_, y2)| (y1 - y2).abs < 0.01 },
      "nothing in it runs level"
  end

  # The one that keeps the affordance honest. If what you can see and what you
  # can point at are different places, you learn that pointing does not work.
  test "every name carries its own marker, so pointing at one finds the other" do
    grove = Grove.draw

    assert_equal grove.offerings, grove.labels.filter_map { |label| label[:offering] }
    assert_equal grove.ravens,    grove.labels.filter_map { |label| label[:raven] }
  end

  # A thing on a cord has nothing holding it out to one side, so the disc is
  # centred under the knot rather than swung out from it.
  test "an offering rests directly under its own knot" do
    Grove.draw.offerings.select { |offering| offering[:state] == "hung" }.each do |offering|
      # Every number in the path is half of an "x y" pair, so the evens are the
      # across and the odds are the down.
      xs = offering[:disc].scan(/-?\d+(?:\.\d+)?/).map(&:to_f).each_slice(2).map(&:first)

      assert offering[:cord] > 0, "it is hanging from something"
      assert_in_delta 0.0, (xs.min + xs.max) / 2, offering[:r] * 0.1,
        "#{offering[:node].name}: its disc is off to one side of the cord"
    end
  end

  # A cord has to start on something. Offsetting the knot sideways from a limb
  # tip put it in open air, because a limb tapers to nothing at its tip and
  # does not run vertically to begin with.
  test "a cord is tied to wood, not to the air beside it" do
    # A live crowned node is the case that matters and the one the fixtures do
    # not have: the server is down, so it drops its offering instead of hanging
    # it, and every other fixture node is bare infrastructure.
    nas = Node.create!(name: "Vault", kind: "nas", status: "up")
    Link.create!(from_node: nodes(:switch), to_node: nas, kind: "ethernet")
    Service.create!(node: nas, name: "shares", url: "http://example.invalid")

    grove = Grove.draw

    assert grove.labels.any? { |label| label[:node] == nas && label[:offering] }

    grove.labels.filter_map { |label| label[:offering] }
         .select { |offering| offering[:state] == "hung" }.each do |offering|
      knot = [ offering[:x], offering[:y] ]
      near = grove.boughs.map { |bough|
        Math.hypot(bough[:knot][0] - knot[0], bough[:knot][1] - knot[1])
      }.min

      assert_in_delta 0.0, near, 0.5,
        "#{offering[:node].name}: its knot is #{near.round(1)} from any limb's surface"
    end
  end

  # What keeps a row of them from reading as rivets is the drop, not an offset.
  test "no two cords are the same length, and the long ones swing slower" do
    hung = Grove.draw.offerings.select { |offering| offering[:state] == "hung" }
    cords = hung.map { |offering| offering[:cord] }

    assert_equal cords.uniq, cords

    # A pendulum's period goes with the square root of its length.
    by_length = hung.sort_by { |offering| offering[:cord] }

    assert_equal by_length.map { |offering| offering[:dur] }.sort,
                 by_length.map { |offering| offering[:dur] }
  end

  # Ornament swinging in lockstep is ornament painted on.
  test "no two offerings swing together" do
    hung = Grove.draw.offerings.select { |offering| offering[:state] == "hung" }
    beat = hung.map { |offering| [ offering[:dur], offering[:delay] ] }

    assert_equal beat.uniq, beat
  end

  test "a fallen offering is not still swinging from something" do
    nodes(:server).update!(status: "down")

    down = Grove.draw.offerings.find { |offering| offering[:node] == nodes(:server) }

    assert_equal "fallen", down[:state]
    assert_equal 0, down[:cord]
    assert_nil down[:beads], "and there is no cord left to be strung"
  end

  private
    def clear_canvas
      Link.delete_all
      Service.delete_all
      Node.delete_all
    end
end
