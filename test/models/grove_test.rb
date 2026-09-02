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

  # The plate grew rather than the dependencies being dropped. Capped at nine
  # slots, the tenth and everything after it vanished with no mark at all --
  # from a picture whose whole claim is that nothing in it is new information.
  test "a network that leans on more things than the plate holds grows the plate" do
    twelve = 12.times.map { |i| Node.create!(name: "Box #{i}", kind: "server", status: "up") }
    twelve.each { |node| Link.create!(from_node: nodes(:switch), to_node: node, kind: "logical", label: "x") }

    grove = Grove.draw
    buried = grove.offerings.select { |offering| offering[:state] == "buried" }

    assert_equal 13, buried.size, "the router and all twelve boxes are down there"
    assert_equal (twelve + [ nodes(:router) ]).to_set, buried.map { |o| o[:node] }.to_set
    assert grove.rootwood.size >= 13, "and every one of them has a root"
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

  # ── the cache stamp ─────────────────────────────────────────────────────
  #
  # The scene is cached on this, so it has to move for everything the drawing
  # reads and stay still for everything it does not. Staying still is the half
  # that is easy to get wrong in the safe direction: a stamp that moves too
  # often is merely slow, and one that moves too little shows you a tree that
  # is no longer true.

  test "the same network stamps the same twice" do
    assert_equal Grove.stamp, Grove.stamp
  end

  test "everything the picture is drawn from moves the stamp" do
    {
      "a node going down"      => -> { nodes(:router).update!(status: "down") },
      "a node being renamed"   => -> { nodes(:router).update!(name: "Gateway") },
      "a node changing kind"   => -> { nodes(:router).update!(kind: "modem") },
      "a service going down"   => -> { services(:plex).update!(status: "down") },
      "a new cable"            => -> { Link.create!(from_node: nodes(:internet), to_node: nodes(:switch), kind: "ethernet") },
      "a cable being relabelled" => -> { links(:dns).update!(label: "NTP") },
      "a new node"             => -> { Node.create!(name: "New", kind: "host") },
      "a fresh speedtest"      => -> { Speedtest.create!(down_mbps: 500, up_mbps: 20, latency_ms: 9) }
    }.each do |what, change|
      before = Grove.stamp
      change.call

      assert_not_equal before, Grove.stamp, "#{what} left the stamp where it was"
    end
  end

  # A light theme hangs a sun where the moon was, and that is markup rather
  # than a colour, so it belongs in the key.
  test "the theme being the other way up moves the stamp" do
    before = Grove.stamp
    was = Omarchy.method(:mode)
    Omarchy.define_singleton_method(:mode) { "light" }

    assert_not_equal before, Grove.stamp
  ensure
    Omarchy.define_singleton_method(:mode, was)
  end

  # The one that keeps the cache worth having. A probe stamps every node it
  # visits whether or not anything moved; if that moved the key, the tree would
  # be regrown every sweep to arrive at exactly the same picture.
  test "a probe that found nothing new leaves the stamp alone" do
    before = Grove.stamp

    nodes(:router).update!(last_probed_at: Time.current, latency_ms: 42)
    nodes(:router).touch

    assert_equal before, Grove.stamp
  end

  # ── ravens ──────────────────────────────────────────────────────────────

  # A bird on the ground is how this picture says a node is down. Putting one
  # there for any other reason is the picture telling you a thing that is not
  # so -- and it did, whenever the tree happened to offer nowhere to perch.
  test "only a node that is down is drawn hunting on the ground" do
    Node.create!(name: "Hetzner", kind: "vps", status: "up",   probe_kind: "none")
    Node.create!(name: "OVH",     kind: "vps", status: "down", probe_kind: "none")

    Grove.draw.ravens.each do |raven|
      assert_equal raven[:node].status_down?, raven[:pose] == "hunting",
        "#{raven[:node].name} is #{raven[:node].status} and drawn #{raven[:pose]}"
    end
  end

  # Every limb dead leaves no live tip to stand on, but there is still wood.
  test "a raven that is up still perches when every limb is dead" do
    Node.where.not(kind: "internet").update_all(status: "down")
    vps = Node.create!(name: "Hetzner", kind: "vps", status: "up", probe_kind: "none")

    raven = Grove.draw.ravens.find { |r| r[:node] == vps }

    assert_equal "perched", raven[:pose], "an up node was put on the ground"
    assert raven[:y] < Grove::GROUND, "and it is in the tree, not on the floor"
  end

  # Two of them on one twig read as one bird, and one of the two nodes then has
  # nothing on screen at all.
  test "no two ravens land on the same spot" do
    %w[ Hetzner OVH Linode ].each do |name|
      Node.create!(name: name, kind: "vps", status: "up", probe_kind: "none")
    end

    ravens = Grove.draw.ravens

    assert_equal 3, ravens.size
    ravens.combination(2).each do |one, other|
      apart = Math.hypot(one[:x] - other[:x], one[:y] - other[:y])

      assert apart > 40, "#{one[:node].name} and #{other[:node].name} are #{apart.round} apart"
    end
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

  # Two discs on one spot read as one disc, and then one of the two nodes has
  # nothing on screen you could point at. The plate is where this bites: the
  # roots nearest the trunk are the closest together, and the heaviest
  # dependencies are exactly the ones sent there.
  test "no two offerings are drawn on top of each other" do
    pi = Node.create!(name: "Pi-hole", kind: "raspberry pi", status: "up")
    Link.create!(from_node: nodes(:switch), to_node: pi, kind: "ethernet")
    [ nodes(:server), nodes(:internet) ].each do |leaner|
      Link.create!(from_node: leaner, to_node: pi, kind: "logical", label: "DNS")
    end

    discs = Grove.draw.offerings.map { |offering|
      [ offering[:node], offering[:x], offering[:y] + offering[:top] + offering[:r], offering[:r] ]
    }

    assert discs.size > 2

    discs.combination(2).each do |(one, ax, ay, ar), (other, bx, by, br)|
      apart = Math.hypot(ax - bx, ay - by)

      assert apart > ar + br,
        "#{one.name} and #{other.name} are #{apart.round} apart and need #{(ar + br).round}"
    end
  end

  # A mark shared with the next node is a mark you cannot learn one node by.
  # Compared as raw paths these differ by where they hang, so the shape has to
  # be lifted off its own baseline before two of them can be told apart.
  test "every node wears its own bind-rune, and the same one twice running" do
    worn = Grove.draw.offerings.group_by { |offering| offering[:node] }
                .transform_values { |offerings| offerings.map { |o| rune_shape(o) } }

    assert worn.size > 3

    worn.each do |node, shapes|
      assert shapes.all? { |shape| same_rune?(shapes.first, shape) },
        "#{node.name} wears more than one mark"
    end

    worn.values.map(&:first).combination(2).each do |one, other|
      assert_not same_rune?(one, other), "two nodes wear the same mark"
    end

    again = Grove.draw.offerings.group_by { |offering| offering[:node] }
                 .transform_values { |offerings| rune_shape(offerings.first) }

    worn.each { |node, shapes| assert same_rune?(shapes.first, again[node]), "#{node.name} changed between draws" }
  end

  # The mark is the node's, so it cannot move for a reason that is not the
  # node's. Handed the caller's rng this was seeded by whatever had drawn from
  # it already, and `shed` draws once per dead service.
  test "a node keeps its mark when a service inside it dies" do
    nas = Node.create!(name: "Vault", kind: "nas", status: "up")
    Link.create!(from_node: nodes(:switch), to_node: nas, kind: "ethernet")
    2.times { |i| Service.create!(node: nas, name: "s#{i}", url: "http://example.invalid/#{i}") }

    before = rune_shape(offering_for(nas))
    nas.services.first.update!(status: "down")

    assert_equal before, rune_shape(offering_for(nas)), "its own mark moved because something else did"
  end

  # Nor for a reason that is another node's.
  test "a provider keeps its mark when a heavier one outranks it" do
    before = rune_shape(buried_for(nodes(:router)))

    pi = Node.create!(name: "Pi-hole", kind: "raspberry pi", status: "up")
    Link.create!(from_node: nodes(:switch), to_node: pi, kind: "ethernet")
    [ nodes(:server), nodes(:internet) ].each do |leaner|
      Link.create!(from_node: leaner, to_node: pi, kind: "logical", label: "DNS")
    end

    assert_equal before, rune_shape(buried_for(nodes(:router))),
      "the router's mark moved because a different node arrived"
  end

  # A node drawn twice is still one node, and a mark that told you otherwise
  # would be telling you something untrue.
  test "a node that appears twice wears the same mark in both places" do
    router = Grove.draw.offerings.select { |offering| offering[:node] == nodes(:router) }

    assert_equal 2, router.size, "the router is in the canopy and under the plate"
    assert same_rune?(rune_shape(router.first), rune_shape(router.last))
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

  # The highlight has to appear around the thing the cursor found. Anchored to
  # the limb instead, it drew itself a cord's length above the token.
  test "the ring and the target are centred on the marker, not on the wood" do
    Node.create!(name: "Hetzner", kind: "vps", status: "up")

    Grove.draw.labels.each do |label|
      centre = if (o = label[:offering])
        [ o[:x], o[:y] + o[:top] + o[:r] ]
      else
        r = label[:raven]
        [ r[:x], r[:y] - 14 * r[:scale] ]
      end

      assert_in_delta centre[0], label[:x], 0.1, "#{label[:node].name}: ring is off sideways"
      assert_in_delta centre[1], label[:y], 0.1, "#{label[:node].name}: ring is off vertically"

      next unless label[:offering]

      # It must still contain the disc at the far end of its own swing.
      swing = (label[:offering][:top] + label[:offering][:r]) * Math.sin(2.2 * Math::PI / 180)

      assert label[:ring] > label[:offering][:r] + swing.abs,
        "#{label[:node].name}: the disc swings out of its own ring"
      assert label[:hit] > label[:offering][:r] * 0.82 + swing.abs,
        "#{label[:node].name}: the disc swings out of its own target"
    end
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
    # The rune, lifted off whatever height it happens to hang at, so two of them
    # can be compared as marks rather than as positions.
    def rune_shape(offering)
      offering[:marks].scan(/-?\d+(?:\.\d+)?/).map(&:to_f).each_slice(2)
        .map { |x, y| [ x, y - offering[:top] ] }
    end

    # Compared within a tolerance rather than by rounding. The path is written
    # at one decimal place, so lifting `top` back off a number that was rounded
    # together with it leaves a twentieth of a unit behind either way -- and two
    # values a hundredth apart can still land on opposite sides of a rounding
    # boundary. Runes differ from each other by whole units, so a fifth of one
    # tells them apart with room to spare.
    def same_rune?(one, other)
      one.size == other.size &&
        one.zip(other).all? { |(ax, ay), (bx, by)| (ax - bx).abs < 0.2 && (ay - by).abs < 0.2 }
    end

    def offering_for(node)
      Grove.draw.offerings.find { |offering| offering[:node] == node && offering[:state] != "buried" }
    end

    def buried_for(node)
      Grove.draw.offerings.find { |offering| offering[:node] == node && offering[:state] == "buried" }
    end

    def clear_canvas
      Link.delete_all
      Service.delete_all
      Node.delete_all
    end
end
