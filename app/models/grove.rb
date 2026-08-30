# The same network, grown instead of drawn.
#
# Nothing here is new information. Every branch, crown and raven is the graph in
# Node and Link read a second way: the internet is the trunk because that is
# where the packets enter, a switch is a fork because forking is what a switch
# does, and a limb is thick because a lot of the network hangs off it. The
# botany is a rendering of the topology, not a decoration laid over one.
#
# What makes it look like a tree rather than a diagram of one is that the
# network limbs are only the first few forks. Past them the wood keeps dividing
# on its own — five more generations of it, and the same again underground —
# because that recursion is what a tree actually is, and no amount of shading
# on a bare stick will stand in for it.
#
# All of the geometry is computed here, once per render, and the view receives
# finished path data. There is no layout engine in the browser and no drawing
# API anywhere — what arrives is an SVG document, which means every leaf on it
# is themeable by the same custom properties as the rest of Uplink.
class Grove
  # The scene's own coordinate space. The SVG scales to whatever window it
  # lands in, so these are proportions with units bolted on, not pixels.
  W      = 1600.0
  H      = 900.0
  GROUND = 762.0
  BASE_X = 610.0

  # Where the light comes from, and therefore which side of every limb is lit.
  # The orb hangs here and the shading is computed against it, so moving one
  # moves the other.
  ORB   = [ 286.0, 150.0 ].freeze
  LIGHT = [ -0.60, -0.80 ].freeze

  # Gear that carries the network rather than living on it. These grow bare
  # forks. Everything else grows a crown, which is the whole grammar of the
  # picture: infrastructure is wood, the things you actually use are leaves.
  STRUCTURAL = [ "internet", "modem", "router", "switch", "access point" ].freeze

  TRUNK_RADIUS = 44.0
  SPREAD       = 2.9 # radians of sky the whole canopy is allowed to fill

  # How many generations of wood grow past the last node. Each one roughly
  # doubles, so five is the difference between a coat rack and a canopy.
  RAMIFY = 5
  ROOTS  = 5

  # Stroke width per generation, thickest first. The view turns these into one
  # path element each, so the whole tangle costs five elements rather than a
  # thousand.
  TWIG = { 5 => 2.7, 4 => 2.0, 3 => 1.45, 2 => 1.0, 1 => 0.65 }.freeze

  # Two different questions, both answered by the same number. How much of the
  # network hangs off a limb sets how THICK it is. How much it diverges from the
  # limb it grew out of sets how LONG it is — so a switch carrying most of the
  # traffic stays a short, fat continuation of the trunk, and the twig off to
  # one side reaches. Conflating the two is what turns a tree into a spire.
  RUN_SPAN  = 76.0
  FORK_SPAN = 380.0

  # Where the finished tree has to fit, whatever shape the network turns out to
  # be. Growth happens in the tree's own units and is then scaled into this box
  # in one step, which is why adding an eighth branch cannot push the canopy off
  # the top of the frame.
  FRAME    = { x: 636.0, top: 86.0, width: 1120.0 }.freeze
  MAX_ZOOM = 1.7
  STRETCH  = 1.55 # how much wider than tall the fit may pull it. Oaks do this.

  attr_reader :boughs, :twigs, :grain, :foliage, :crowns, :litter, :falling, :ravens, :labels,
              :speedtest, :internet

  def self.draw(...) = new(...)

  # The whole picture is the unit of redraw. Rendering it costs single-digit
  # milliseconds and a status change is rare, so there is nothing here to patch
  # in place — and the alternative, replacing one <g> inside the SVG, does not
  # survive the trip: a Turbo Stream arrives in a <template>, where a bare <g>
  # parses as an unknown HTML element rather than as SVG.
  def self.redraw
    Turbo::StreamsChannel.broadcast_replace_later_to "grove",
      target: "grove-scene", partial: "grove/scene"
  end

  def initialize(nodes: Node.ordered.includes(:services), links: Link.where.not(kind: "logical"))
    @nodes  = nodes.to_a
    @links  = links.to_a
    @boughs = []
    @crowns = []
    @litter = []
    @falling = []
    @ravens = []
    @labels = []
    @limbs  = []
    @twigs   = Hash.new { |bucket, depth| bucket[depth] = [] }
    @foliage = []
    @grain   = []
    @tips   = []
    @rooted = {}

    @speedtest = Speedtest.latest
    @internet  = @nodes.find(&:internet?)

    # Three passes, in the order a person would draw it: work out where the
    # tree goes, size it to the paper, then ink it.
    place
    fit
    render
    perch
  end

  # The sky's one reading, and it is a size rather than a number. Radius follows
  # the square root of the download, so a gigabit line hangs a visibly larger
  # moon than a DSL one without being twenty times the size of it — and the moon
  # stays a moon, with nothing printed on it.
  def orb
    mbps = speedtest&.ok? ? speedtest.down_mbps.to_f : 0.0
    { x: ORB[0], y: ORB[1], r: (32 + 32 * Math.sqrt([ mbps, 2000.0 ].min / 900.0)).round(1) }
  end

  # The one state that changes the whole scene rather than one branch of it.
  def eclipsed? = internet.present? && internet.status_down?

  # Sun by day, moon by night — and the desktop decides which, because the
  # theme's own `mode` is already the most considered statement anyone on this
  # machine has made about whether it is dark out.
  def night? = Omarchy.mode != "light"

  def stars
    return [] unless night?

    rng = Seeded.new(20_260_830)
    110.times.map do
      y = rng.between(4, 560)
      { x: rng.between(4, W - 4).round(1), y: y.round(1),
        r: rng.between(0.4, 1.5).round(2),
        # Aerial perspective, applied to the sky: stars thin out into the
        # horizon haze rather than stopping at a line.
        o: (rng.between(0.2, 0.85) * (1 - (y / 660.0))).round(3),
        delay: rng.between(0, 11).round(1) }
    end
  end

  # Everything with services, for the stone. Grouped by the node that runs them,
  # because "where does this live" is the question a list like this is actually
  # asked.
  # Stroke width for one generation of twig, in the scene's units.
  def twig_width(depth) = (TWIG.fetch(depth, 0.6) * @zoom).round(2)

  # Scenery, and the only thing in the frame that is not a row in the database:
  # a treeline on the ridge so the one tree that means something has a wood to
  # stand in front of. Grown by the same recursion, then flattened into a single
  # hazy stroke — which is what distance does.
  def thicket
    @thicket ||= [].tap do |wood|
      rng = Seeded.new(77_041)

      26.times do
        x = rng.between(-40, W + 40)
        next if x.between?(FRAME[:x] - 330, FRAME[:x] + 330) || x > 1200

        base   = 708 + rng.between(-16, 22)
        height = rng.between(24, 56)

        wood << "M#{xy(x, base)}L#{xy(x + rng.between(-4, 4), base - height)}"
        ramify [ x, base - height ], -Math::PI / 2, height * 0.6, 4, rng, [], sink: wood
      end
    end
  end

  def rosters
    @nodes.select { |node| node.services.any? }.map { |node| [ node, node.services.to_a ] }
  end

  private
    # A tree that reshuffles itself every time you look at it is not a diagram.
    # Each node seeds its own generator from its own id, so its jitter is fixed
    # for the life of the row and adding a fourteenth node leaves the other
    # thirteen exactly where they were.
    class Seeded
      def initialize(seed)
        @state = (seed.to_i * 2_654_435_761) % 4_294_967_291
      end

      def next
        @state = (@state * 1_103_515_245 + 12_345) % 2_147_483_648
        @state / 2_147_483_648.0
      end

      def between(low, high) = low + (high - low) * self.next
    end

    # ── the graph, before it is a tree ───────────────────────────────────

    def degrees
      @degrees ||= Hash.new(0).merge(adjacency.transform_values(&:size))
    end

    def adjacency
      @adjacency ||= Hash.new { |map, id| map[id] = [] }.tap do |map|
        @links.each do |link|
          map[link.from_node_id] << link.to_node_id
          map[link.to_node_id]   << link.from_node_id
        end
      end
    end

    # A LAN is very nearly a tree already; the spanning walk is what makes it
    # exactly one. A second path back to the switch is a redundant cable, not a
    # second branch, so the first way we reach a node is the way it grows — and
    # a ring of switches cannot send this into a loop.
    def spanning_order(root)
      by_id = @nodes.index_by(&:id)
      order = Hash.new { |map, id| map[id] = [] }
      queue = [ root ]
      @rooted[root.id] = true

      while (node = queue.shift)
        adjacency[node.id].sort.each do |id|
          next if @rooted[id] || by_id[id].nil?

          @rooted[id] = true
          order[node.id] << by_id[id]
          queue << by_id[id]
        end
      end

      order
    end

    # How much of the canopy hangs off each node. This is what sets a limb's
    # thickness, so it is the number that makes the picture informative.
    def leaf_counts(root)
      counts = {}
      count = ->(node) { counts[node.id] = @order[node.id].sum { |kid| count.(kid) }.nonzero? || 1 }
      count.(root)
      counts
    end

    # ── pass one: where everything goes, in the tree's own units ─────────

    def place
      root = @internet || @nodes.max_by { |node| degrees[node.id] }
      return if root.nil?

      @order  = spanning_order(root)
      @leaves = leaf_counts(root)

      grow root, from: [ BASE_X, GROUND ], angle: -Math::PI / 2, span: RUN_SPAN * 1.35,
           radius: TRUNK_RADIUS, sector: SPREAD, depth: 0
    end

    # Places the limb that arrives at `node`, then divides the sky above it
    # among the things that hang off it. One method, called once per node, which
    # is the same shape as the recursion in the network itself.
    def grow(node, from:, angle:, span:, radius:, sector:, depth:)
      rng  = Seeded.new(node.id)
      kids = @order[node.id]
      dead = node.status_down?

      # A dead limb that was carrying nothing snaps off short. A dead limb with
      # branches beyond it keeps its length and goes to dead wood instead —
      # because Uplink probes every node for itself, and the things behind a
      # switch that stopped answering may very well still be answering. Dropping
      # them out of the tree would be drama at the cost of the truth.
      snapped = dead && kids.empty?
      reach   = snapped ? span * 0.5 : span
      to    = [ from[0] + Math.cos(angle) * reach, from[1] + Math.sin(angle) * reach ]

      # A limb narrows along its length and again at every fork. The tip is
      # where its children start, so their radius is measured from it rather
      # than from the base — which is the difference between a tree and a stack
      # of cylinders with a step at every joint.
      tip = [ radius * (kids.empty? ? 0.5 : 0.84), 2.6 ].max

      @limbs << { node: node, from: from, to: to, angle: angle, depth: depth, dead: dead,
                  r0: radius, r1: tip, bow: span * rng.between(-0.2, 0.2),
                  crowned: !STRUCTURAL.include?(node.kind) || kids.empty? }

      return if kids.empty?

      total  = kids.sum { |kid| @leaves[kid.id] }
      bend   = [ 0.66 + 0.08 * depth, 0.96 ].min
      cursor = angle - sector / 2.0

      # The heaviest limb carries the trunk on from the tip; the rest leave
      # further back down it, in the order they were allotted their sky. Six
      # branches from one point is a candelabra. Six branches from six points up
      # the same run is a tree.
      trunk = kids.max_by { |kid| @leaves[kid.id] }
      steps = kids.reject { |kid| kid == trunk }

      kids.each_with_index do |kid, i|
        share  = @leaves[kid.id] / total.to_f
        slice  = sector * share
        aim    = cursor + slice / 2.0
        cursor += slice

        along = if kid == trunk
          1.0
        else
          rank = steps.index(kid)
          0.44 + 0.5 * (steps.one? ? 0.6 : rank / (steps.size - 1.0)) + rng.between(-0.04, 0.04)
        end

        # Pull the limb back toward the direction it grew from. A branch that
        # took its whole allotted angle would splay like a hand; a real one
        # leaves the trunk reluctantly and straightens as it goes.
        heading = angle + (aim - angle) * bend + rng.between(-0.07, 0.07)

        grow kid, from: lerp(from, to, along), angle: heading, depth: depth + 1,
             span:   RUN_SPAN + (FORK_SPAN - RUN_SPAN) * (1 - share),
             radius: [ (radius + (tip - radius) * along) * Math.sqrt(share), 2.8 ].max,
             sector: [ slice, [ 0.34 * @order[kid.id].size, sector * 0.9 ].min ].max
      end
    end

    def lerp(from, to, t)
      [ from[0] + (to[0] - from[0]) * t, from[1] + (to[1] - from[1]) * t ]
    end

    # ── pass two: the same tree, sized to the paper ──────────────────────

    # Every network grows a differently shaped tree and none of them know how
    # big the window is, so rather than tuning constants until one topology
    # happens to fit, the whole thing is measured once and scaled about its own
    # base. The base stays planted, because the one point in this picture that
    # is not free to move is where the trunk meets the ground.
    def fit
      xs = @limbs.flat_map { |limb| [ limb[:from][0], limb[:to][0] ] }
      ys = @limbs.flat_map { |limb| [ limb[:from][1], limb[:to][1] ] }
      return if xs.empty?

      # The bare limbs are only the first few forks; five more generations grow
      # past every tip, and they reach about as far again as the limb they came
      # from. Measuring the limbs alone is what put the canopy off the top of
      # the frame the first time.
      canopy = @limbs.map { |limb| Math.hypot(limb[:to][0] - limb[:from][0], limb[:to][1] - limb[:from][1]) }.max * 0.9

      @zoom = [ (GROUND - FRAME[:top]) / [ GROUND - ys.min + canopy, 1.0 ].max, MAX_ZOOM ].min
      @wide = [ FRAME[:width] / [ xs.max - xs.min + canopy * 1.5, 1.0 ].max, @zoom * STRETCH ].min
      @base = FRAME[:x] - ((xs.min + xs.max) / 2 - BASE_X) * @wide
    end

    # Height and width scale by different amounts, within limits. A tree pulled
    # half again as wide as it grew is still an entirely believable tree — there
    # is one in every park — and it is the difference between filling the frame
    # and standing in the middle of it like a cypress. Thickness follows the
    # vertical scale only, so the limbs stay round.
    def scaled(point)
      [ @base + (point[0] - BASE_X) * @wide, GROUND + (point[1] - GROUND) * @zoom ]
    end

    # ── pass three: ink ──────────────────────────────────────────────────

    def render
      return if @limbs.empty?

      flare
      @limbs.each { |placed| ink(placed) }
    end

    def ink(placed)
      rng    = Seeded.new(placed[:node].id)
      from   = scaled(placed[:from])
      to     = scaled(placed[:to])
      r0, r1 = placed[:r0] * @zoom, placed[:r1] * @zoom
      run    = Math.hypot(to[0] - from[0], to[1] - from[1])

      @boughs << limb(from, to, r0, r1, placed[:bow] * @zoom,
                      dead: placed[:dead], angle: placed[:angle], rng: rng)
      striate(from, to, r0, r1, rng)
      @tips << { x: to[0], y: to[1], angle: placed[:angle], r: r1 } unless placed[:dead]

      # Wood coming off the sides of the limb, not only from its end. Without
      # this the network's own forks read as the whole tree, and a tree with
      # eleven branches in it is a diagram.
      3.times do
        along = rng.between(0.34, 0.92)
        ramify lerp(from, to, along),
               placed[:angle] + (rng.next < 0.5 ? -1 : 1) * rng.between(0.45, 0.95),
               run * rng.between(0.2, 0.34), RAMIFY - 2, rng, []
      end

      # And the generations past the tip, which are most of what you see.
      tips = []
      ramify to, placed[:angle], run * 0.44, placed[:dead] ? RAMIFY - 2 : RAMIFY, rng, tips

      size = crown_size(placed[:node])

      if placed[:dead]
        fell(placed[:node], to, size, rng)
        return
      end

      leaf_out(placed[:node], tips, rng) if placed[:crowned]
      shed(placed[:node], to, size, rng)
      crowned(placed[:node], to, size) if placed[:crowned]
      label(placed[:node], to, placed[:crowned] ? size : r0)
    end

    # One generation of wood, then the same again from each of its ends. Every
    # segment goes into a bucket by generation, and the view draws each bucket
    # as a single path at a single stroke width — so a thousand twigs cost five
    # elements and the line quality stays even, the way an engraving's does.
    def ramify(from, angle, span, depth, rng, tips, reach: true, sink: nil)
      return if depth <= 0 || span < 2.5

      forks = depth >= 4 ? 2 : (rng.next < 0.74 ? 2 : 3)

      forks.times do |i|
        lean    = rng.between(0.24, 0.68) * (i.even? ? -1 : 1)
        lean   *= 0.4 if i == 2
        heading = angle + lean + rng.between(-0.14, 0.14)
        len     = span * rng.between(0.58, 0.86)
        to      = [ from[0] + Math.cos(heading) * len, from[1] + Math.sin(heading) * len ]

        (sink || @twigs[[ depth, RAMIFY ].min]) <<
          "M#{xy(*from)}Q#{xy(*curl(from, to, heading, len, reach))} #{xy(*to)}"
        tips << to if depth == 1

        ramify to, heading, len, depth - 1, rng, tips, reach: reach, sink: sink
      end
    end

    # The same phototropism the limbs have, at twig scale: a horizontal run
    # bows upward, a vertical one barely bends. Underground it is inverted,
    # because a root is doing the opposite job.
    def curl(from, to, heading, len, reach)
      nx, ny = -Math.sin(heading), Math.cos(heading)
      bend   = (ny.negative? ? 1 : -1) * len * 0.24 * ny.abs
      bend   = -bend unless reach

      [ (from[0] + to[0]) / 2 + nx * bend, (from[1] + to[1]) / 2 + ny * bend ]
    end

    # Grain, cut along the limb. Three or four fine lines are the difference
    # between wood and a smooth grey tube, and it is the same move the twigs
    # already make — the whole tree is drawn in one kind of mark.
    def striate(from, to, r0, r1, rng)
      return if r0 < 7

      (r0 / 3.2).round.clamp(2, 7).times do
        across = rng.between(-0.62, 0.62)
        dx, dy = to[0] - from[0], to[1] - from[1]
        len    = Math.hypot(dx, dy).nonzero? || 1.0
        nx, ny = -dy / len, dx / len
        head   = rng.between(0.04, 0.3)
        tail   = rng.between(0.62, 0.98)

        a = [ from[0] + dx * head + nx * r0 * across, from[1] + dy * head + ny * r0 * across ]
        b = [ from[0] + dx * tail + nx * r1 * across * 1.2, from[1] + dy * tail + ny * r1 * across * 1.2 ]
        c = [ (a[0] + b[0]) / 2 + nx * rng.between(-2.5, 2.5), (a[1] + b[1]) / 2 + ny * rng.between(-2.5, 2.5) ]

        @grain << "M#{xy(*a)}Q#{xy(*c)} #{xy(*b)}"
      end
    end

    def crown_size(node)
      size = 58 + 11 * Math.sqrt(node.services.size)
      size *= 0.66 if STRUCTURAL.include?(node.kind)
      (size * @zoom).round(1)
    end

    # Kept for the label's hit target and for the tests: where the foliage is
    # and what state it is in. The leaves themselves are drawn from the twigs.
    def crowned(node, spot, size)
      @crowns << { node: node, state: node.rollup_status,
                   x: spot[0].round(1), y: spot[1].round(1), r: size }
    end

    def perches
      thin = @tips.select { |tip| tip[:r] < 16 }
      thin.any? ? thin : @tips
    end

    # One limb, as an outline rather than a stroke, so it can be thick where it
    # leaves the trunk and thin where it ends — which a stroke cannot do.
    #
    # The two slivers are the shading. A branch is a cylinder, so the side
    # facing the orb carries a highlight and the far side a shadow, and how
    # strongly depends on how side-on the limb is to the light. That is one dot
    # product, and it is most of the difference between a diagram and a drawing.
    def limb(from, to, r0, r1, bow, dead:, angle:, rng:, reach: true)
      dx, dy = to[0] - from[0], to[1] - from[1]
      len    = Math.hypot(dx, dy).nonzero? || 1.0
      nx, ny = -dy / len, dx / len
      facing = nx * LIGHT[0] + ny * LIGHT[1]
      side   = facing.negative? ? -1.0 : 1.0

      # Phototropism. A limb heading sideways arcs upward along its length, and
      # one heading straight up does not — the strength of the bend is exactly
      # how horizontal the limb is. It is the difference between a tree that
      # grew and a tree drawn with a ruler, and it costs one term.
      bow -= (ny.negative? ? -1 : 1) * len * 0.16 * ny.abs if reach

      { body:  taper(from, to, r0, r1, bow, nx, ny),
        lit:   taper(shift(from, nx, ny, side * r0 * 0.62), shift(to, nx, ny, side * r1 * 0.62),
                     r0 * 0.22, r1 * 0.22, bow, nx, ny),
        shade: taper(shift(from, nx, ny, -side * r0 * 0.52), shift(to, nx, ny, -side * r1 * 0.52),
                     r0 * 0.36, r1 * 0.36, bow, nx, ny),
        glare: (facing.abs * 0.5).round(3),
        joint: [ to[0].round(1), to[1].round(1), (r1 * 1.02).round(1) ],
        splinter: (splinter(to, angle, r1, rng) if dead),
        dead: dead }
    end

    def taper(from, to, r0, r1, bow, nx, ny)
      cx = (from[0] + to[0]) / 2 + nx * bow
      cy = (from[1] + to[1]) / 2 + ny * bow
      rm = (r0 + r1) / 2

      "M#{xy(from[0] + nx * r0, from[1] + ny * r0)}" \
      "Q#{xy(cx + nx * rm, cy + ny * rm)} #{xy(to[0] + nx * r1, to[1] + ny * r1)}" \
      "L#{xy(to[0] - nx * r1, to[1] - ny * r1)}" \
      "Q#{xy(cx - nx * rm, cy - ny * rm)} #{xy(from[0] - nx * r0, from[1] - ny * r0)}Z"
    end

    # Where a limb tore rather than ended.
    def splinter(spot, angle, r, rng)
      ux, uy = Math.cos(angle), Math.sin(angle)
      nx, ny = -uy, ux

      points = (0..4).map do |i|
        across = -1.0 + i * 0.5
        out    = rng.between(0.3, 2.1) * r
        xy(spot[0] + nx * across * r + ux * out, spot[1] + ny * across * r + uy * out)
      end

      "M#{xy(spot[0] - nx * r, spot[1] - ny * r)}L#{points.join('L')}L#{xy(spot[0] + nx * r, spot[1] + ny * r)}Z"
    end

    # A canopy. A node whose services are all answering keeps a whole crown; one
    # with a dead service keeps the crown and loses leaves to the ground.
    # Leaves, hung on the twigs that actually exist rather than painted as a
    # mass over them. A node with a dead service inside it browns a share of
    # its own canopy in proportion, which is the same fact the fallen leaves on
    # the floor report, said quietly.
    def leaf_out(node, tips, rng)
      return if tips.empty?

      spoiled = node.services.any? ? node.services.count(&:status_down?) / node.services.size.to_f : 0.0

      tips.each do |tip|
        rng.between(6, 13.4).to_i.times do
          size = rng.between(2.6, 5.4) * @zoom
          @foliage << { d: leaf(tip[0] + rng.between(-7, 7) * @zoom,
                                tip[1] + rng.between(-7, 7) * @zoom,
                                size, rng.between(0, Math::PI)),
                        tone: rng.next < spoiled * 0.55 ? "dead" : "live" }
        end
      end
    end

    # A pointed oval, which is as much leaf as anything four units across needs
    # to be.
    def leaf(x, y, r, a)
      ux, uy = Math.cos(a) * r, Math.sin(a) * r
      nx, ny = -uy * 0.44, ux * 0.44

      "M#{xy(x - ux, y - uy)}Q#{xy(x + nx, y + ny)} #{xy(x + ux, y + uy)}" \
      "Q#{xy(x - nx, y - ny)} #{xy(x - ux, y - uy)}Z"
    end

    # Every dead service is a leaf on the floor. It is the smallest possible
    # statement of "something in there is broken", and it needs no legend.
    def shed(node, spot, size, rng)
      dropped = node.services.count(&:status_down?)
      return unless dropped.positive?

      @litter.concat scatter(spot[0], dropped * 6, rng)
      # A few still on the way down, so the pile on the floor has somewhere
      # obvious to have come from.
      @falling.concat Array.new(dropped * 2) {
        { x: (spot[0] + rng.between(-size * 0.9, size * 0.9)).round(1),
          y: (spot[1] + rng.between(size * 0.4, (GROUND - spot[1]) * 0.9)).round(1),
          r: rng.between(1.8, 3.2).round(2), tilt: rng.between(0, 180).round }
      }
    end

    # Its crown is on the ground under it, and the leaves that were on the way
    # there are around the stump.
    def fell(node, spot, size, rng)
      rest = [ (spot[0] + rng.between(-40, 40)).clamp(90, W - 320), GROUND + rng.between(4, 34) ]

      @crowns << { node: node, state: "fallen", x: rest[0].round(1), y: rest[1].round(1), r: size }

      (size * 0.9).to_i.times do
        @foliage << { d: leaf(rest[0] + rng.between(-size, size),
                              rest[1] + rng.between(-size * 0.3, size * 0.34),
                              rng.between(2.4, 4.6) * @zoom, rng.between(0, Math::PI)),
                      tone: "dead" }
      end

      label(node, rest, size * 0.5)
      @litter.concat scatter(spot[0], 16, rng)
    end

    def scatter(x, count, rng)
      Array.new(count) {
        near = rng.next # 0 is far up the slope, 1 is at the viewer's feet
        { x: (x + rng.between(-100, 100)).clamp(20, W - 300).round(1),
          y: (GROUND - 12 + near * 108).round(1),
          r: (1.3 + near * 2.8).round(2),
          tilt: rng.between(0, 180).round }
      }
    end

    # Hidden until you point at it. The scene is wordless at rest, and the hit
    # target is what the pointer finds — never the text, which would mean
    # hovering something invisible.
    def label(node, spot, radius)
      away = spot[0] < BASE_X ? -1 : 1

      @labels << { node: node, state: node.rollup_status,
                   x: spot[0].round(1), y: spot[1].round(1), hit: [ radius * 1.1, 26.0 ].max.round(1),
                   tx: (spot[0] + away * ([ radius, 26.0 ].max + 8)).round(1),
                   ty: (spot[1] - 4).round(1),
                   anchor: away.negative? ? "end" : "start" }
    end

    # The trunk does not stop at the ground; it splays into it. Five short
    # limbs with no data behind them — this is the one part of the picture that
    # is here only because trees have roots.
    # The trunk does not stop at the ground; it splays into it and keeps
    # dividing. Roots are the one part of the picture with no data behind them,
    # and also the part that decides whether the tree is standing in the world
    # or resting on top of it.
    def flare
      rng = Seeded.new(4_051)

      9.times do |i|
        spread = -1.0 + i / 4.0
        from   = [ @base + spread * 7, GROUND - 20 * @zoom ]
        reach  = rng.between(90, 210) * @wide
        drop   = rng.between(26, 74) * @zoom

        # The middle ones dive rather than spread; the outer ones do the
        # opposite. A root plate is both, and drawing only the fan makes the
        # tree look like it is standing on a doily.
        to = [ @base + spread * reach * (0.35 + 0.65 * spread.abs), GROUND + drop * (1.4 - spread.abs) ]

        @boughs << limb(from, to, TRUNK_RADIUS * (0.34 - 0.06 * spread.abs) * @zoom,
                        rng.between(3.5, 6.5), rng.between(10, 26) * (spread.negative? ? -1 : 1),
                        dead: false, angle: 0, rng: rng, reach: false)

        ramify to, Math.atan2(to[1] - from[1], to[0] - from[0]),
               rng.between(60, 120) * @zoom, ROOTS, rng, [], reach: false
      end
    end

    def perch
      @nodes.reject { |node| @rooted[node.id] }.each do |node|
        rng = Seeded.new(node.id * 31)

        spots = perches

        if node.status_down? || spots.empty?
          x = (BASE_X + (rng.next < 0.5 ? -1 : 1) * rng.between(300, 430)).clamp(150, 1120)
          y = GROUND + rng.between(20, 74)

          @ravens << { node: node, pose: "hunting", scale: 1.5, x: x.round(1), y: y.round(1),
                       flip: rng.next < 0.5 }
          label(node, [ x, y - 30 ], 30)
        else
          spot = spots[(rng.next * spots.size).floor]

          @ravens << { node: node, pose: "perched", scale: 1.25,
                       x: spot[:x].round(1), y: (spot[:y] + spot[:r] * 0.5).round(1),
                       flip: Math.cos(spot[:angle]).negative? }
          label(node, [ spot[:x], spot[:y] - 26 ], 26)
        end
      end
    end

    def shift(point, nx, ny, by) = [ point[0] + nx * by, point[1] + ny * by ]
    def xy(x, y) = "#{x.round(1)} #{y.round(1)}"
end
