# The same network, grown instead of drawn.
#
# Nothing here is new information. Every branch, crown and raven is the graph in
# Node and Link read a second way: the internet is the trunk because that is
# where the packets enter, a switch is a fork because forking is what a switch
# does, and a limb is thick because a lot of the network hangs off it. The
# botany is a rendering of the topology, not a decoration laid over one.
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
  FRAME    = { x: 636.0, top: 100.0, width: 1030.0 }.freeze
  MAX_ZOOM = 1.7
  STRETCH  = 1.55 # how much wider than tall the fit may pull it. Oaks do this.

  attr_reader :boughs, :crowns, :litter, :falling, :ravens, :labels, :speedtest, :internet

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
  # Scenery, and the only thing in the frame that is not a row in the database:
  # a treeline on the ridge so the one tree that means something has a wood to
  # stand in front of. Kept flat, hazy and far, the way distance actually works.
  def thicket
    rng = Seeded.new(77_041)

    24.times.map do
      x = rng.between(-40, W + 40)
      next if x.between?(FRAME[:x] - 330, FRAME[:x] + 330) || x > 1180

      base = 706 + rng.between(-14, 22)
      size = rng.between(13, 30)
      { x: x.round(1), base: base.round(1), size: size.round(1),
        trunk: (size * rng.between(0.7, 1.3)).round(1),
        blobs: blobs(x, base - size * 1.5, size, rng, squash: 1.05) }
    end.compact
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

      canopy = 70.0 # the foliage the bare limbs are about to be dressed in

      @zoom = [ (GROUND - FRAME[:top]) / [ GROUND - ys.min + canopy, 1.0 ].max, MAX_ZOOM ].min
      @wide = [ FRAME[:width] / [ xs.max - xs.min + canopy * 2, 1.0 ].max, @zoom * STRETCH ].min
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

      @boughs << limb(from, to, r0, r1, placed[:bow] * @zoom,
                      dead: placed[:dead], angle: placed[:angle], rng: rng)
      @tips << { x: to[0], y: to[1], angle: placed[:angle], r: r1 } unless placed[:dead]

      return fell(placed[:node], to, rng) if placed[:dead]

      spray(from, to, placed[:angle], r1, rng) if r1 < 13

      unless placed[:crowned]
        shed(placed[:node], to, r0, rng)
        label(placed[:node], to, r0)
        return
      end

      # The crown sits a little past the tip so the limb runs into the leaves
      # rather than stopping short of them, and a few twigs carry on inside.
      size = crown_size(placed[:node])
      seat = [ to[0] + Math.cos(placed[:angle]) * size * 0.42,
               to[1] + Math.sin(placed[:angle]) * size * 0.42 ]

      twigs(to, seat, placed[:angle], r1, size, rng)
      crown(placed[:node], seat, size, rng)
      shed(placed[:node], seat, size, rng)
      label(placed[:node], seat, size)
    end

    # Foliage does not grow on the end of a stick. Four or five thin runs fan
    # out of the tip and end inside the leaf mass, which is what stops a crown
    # from reading as a pom-pom stuck on a pole.
    def twigs(from, seat, angle, radius, size, rng)
      5.times do
        heading = angle + rng.between(-0.85, 0.85)
        reach   = size * rng.between(0.5, 1.15)

        @boughs << limb(from, [ from[0] + Math.cos(heading) * reach,
                                from[1] + Math.sin(heading) * reach ],
                        radius * 0.7, [ radius * 0.24, 1.3 ].max,
                        rng.between(-6, 6), dead: false, angle: heading, rng: rng, fine: true)
      end
    end

    # Bare limbs between the forks are what made the first draft look like a
    # coat rack. A real branch is fuzzy with the twigs it did not need to be
    # drawn as separate nodes, so the outer half of every fine limb gets some.
    def spray(from, to, angle, radius, rng)
      4.times do
        along   = rng.between(0.35, 0.98)
        root    = lerp(from, to, along)
        heading = angle + (rng.next < 0.5 ? -1 : 1) * rng.between(0.35, 0.8)
        reach   = rng.between(16, 40) * @zoom

        @boughs << limb(root, [ root[0] + Math.cos(heading) * reach,
                                root[1] + Math.sin(heading) * reach ],
                        [ radius * 0.5, 2.6 ].min, 0.8, rng.between(-3, 3),
                        dead: false, angle: heading, rng: rng, fine: true)
      end
    end

    def crown_size(node)
      size = 58 + 11 * Math.sqrt(node.services.size)
      size *= 0.66 if STRUCTURAL.include?(node.kind)
      (size * @zoom).round(1)
    end

    # A raven wants a twig: thin, high, and alive. It will settle for a bough
    # if that is all this network has grown.
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
    def limb(from, to, r0, r1, bow, dead:, angle:, rng:, fine: false, reach: true)
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
        glare: (facing.abs * 0.8).round(3),
        joint: [ to[0].round(1), to[1].round(1), (r1 * 1.02).round(1) ],
        splinter: (splinter(to, angle, r1, rng) if dead),
        # A twig is too thin to have a lit side and a dark side, and displacing
        # one by the bark filter pulls it apart into floating specks.
        fine: fine, dead: dead }
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
    def crown(node, spot, size, rng)
      @crowns << { node: node, state: node.rollup_status, x: spot[0].round(1), y: spot[1].round(1),
                   r: size, blobs: blobs(spot[0], spot[1], size, rng),
                   sway: rng.between(0, 8).round(2), period: rng.between(7, 12).round(2) }
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
    def fell(node, spot, rng)
      rest = [ (spot[0] + rng.between(-40, 40)).clamp(90, W - 320), GROUND + rng.between(4, 34) ]
      size = crown_size(node) * 0.95

      @crowns << { node: node, state: "fallen", x: rest[0].round(1), y: rest[1].round(1),
                   r: size.round(1), sway: 0, period: 0,
                   blobs: blobs(rest[0], rest[1], size, rng, squash: 0.32) }
      label(node, rest, size * 0.5)
      @litter.concat scatter(spot[0], 16, rng)
    end

    # Overlapping lumps rather than one circle. Read alone they are nothing;
    # under the ragged-edge filter in the view they become leaf mass.
    # Leaf mass, as lumps. Two rings rather than one, because a single ring of
    # equal circles is a flower; and every crown gets its own aspect and lean,
    # because no two trees in a wood have the same silhouette.
    def blobs(x, y, r, rng, squash: 0.9)
      wide  = rng.between(0.95, 1.35)
      tall  = squash * rng.between(0.82, 1.06)
      lean  = rng.between(-0.3, 0.3)
      lumps = []

      # Three rings. The outer one is what the eye reads as the silhouette, so
      # it is the one with the most variation in it — a canopy whose outline is
      # a circle is a lollipop no matter how it is shaded.
      [ [ 0.86, (r / 5.5).round.clamp(8, 18), 0.3 ],
        [ 0.54, (r / 8).round.clamp(6, 12),   0.42 ],
        [ 0.24, (r / 14).round.clamp(3, 6),   0.5 ] ].each do |ring, count, scale|
        count.times do |i|
          a = (i / count.to_f) * Math::PI * 2 + rng.between(-0.5, 0.5) + lean
          d = r * ring * rng.between(0.66, 1.24)
          bx = Math.cos(a) * d * wide
          by = Math.sin(a) * d * tall

          lumps << { x: (x + bx).round(1), y: (y + by).round(1),
                     r: (r * scale * rng.between(0.5, 1.15)).round(1),
                     lit: (bx * LIGHT[0] + by * LIGHT[1]) > -r * 0.12 }
        end
      end

      lumps << { x: x.round(1), y: (y + r * 0.06).round(1), r: (r * 0.44).round(1), lit: true }
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
    def flare
      rng = Seeded.new(4_051)

      5.times do |i|
        spread = -1.0 + i * 0.5
        from   = [ @base + spread * 4, GROUND - 16 * @zoom ]
        to     = [ @base + spread * rng.between(46, 96) * @wide, GROUND + rng.between(14, 32) ]

        # Roots are the one thing here that is not reaching for the light.
        @boughs << limb(from, to, TRUNK_RADIUS * 0.72 * @zoom, rng.between(4, 7),
                        rng.between(6, 20) * (spread.negative? ? -1 : 1),
                        dead: false, angle: 0, rng: rng, reach: false)
      end
    end

    # Anything the spanning walk never reached is not on this network: a VPS in
    # a datacentre, a box at someone else's house. Those are ravens. One that is
    # answering grips a branch; one that is not is down on the ground a long way
    # from the tree, hunting.
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
