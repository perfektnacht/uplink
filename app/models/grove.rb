# The same network, grown instead of drawn.
#
# Nothing here is new information. Every branch, crown, root and raven is the
# graph in Node and Link read a second way: the internet is the trunk because
# that is where the packets enter, a switch is a fork because forking is what a
# switch does, and a limb is thick because a lot of the network hangs off it.
# The botany is a rendering of the topology, not a decoration laid over one.
#
# The cables are the half above the ground. The half below it is the logical
# links — a dependency that is real but has no wire of its own, which is not a
# branch and is exactly what a root plate is.
#
# Hung in it is one offering per node, which is the only thing here that is
# about reading the picture rather than about being it: the scene is wordless
# until you point at it, and a tag on a cord is what says where there is
# anything to point at.
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
  # Close to the shape of a maximised browser on purpose. The picture is fitted
  # into the window with `meet`, so whatever aspect the viewBox does not use up
  # comes back as letterbox — and since the frame's rails run out past the
  # viewBox to reach the window edge, that letterbox turns into extra wood on
  # two sides only. A frame thicker left and right than top and bottom is that,
  # not a border setting.
  H      = 820.0
  GROUND = 552.0
  BASE_X = 610.0

  # The border the picture is hung in. Everything inside is scene; the frame
  # itself is drawn over the top of it.
  BORDER = 40.0

# The near side, in a unit circle: eight seas, where they actually are and
# with hard edges. Three soft ellipses under a blur made a stone. What makes
# a moon legible is that it has a map on it.
MARIA = [
    # Procellarum running down the western limb, with Imbrium opening off the
    # top of it and Nubium off the bottom — one connected mass, not three
    # circles. This is what the near side actually looks like from a distance,
    # and it is why a moon is recognisable at all.
    "M-.3-.68C-.44-.76-.62-.7-.68-.54C-.74-.4-.66-.28-.7-.14C-.76.02-.84.14-.78.3" \
    "C-.72.46-.56.52-.46.46C-.36.4-.34.26-.26.2C-.16.12-.04.16 0 .06" \
    "C.04-.04-.04-.14-.1-.22C-.16-.3-.12-.42-.18-.52C-.22-.62-.26-.66-.3-.68Z",

    # Serenitatis into Tranquillitatis into Fecunditatis: a chain across the
    # east, pinched between each one.
    "M.1-.56C.24-.66.44-.6.48-.44C.52-.3.42-.2.44-.08C.46.04.6.06.64.18" \
    "C.68.32.6.46.48.48C.36.5.3.4.26.3C.22.2.1.18.06.08" \
    "C.02-.02.1-.12.1-.22C.1-.34.04-.46.1-.56Z",

    # Crisium, which really is an isolated oval out on the edge.
    "M.66-.36C.76-.42.86-.34.86-.22C.86-.1.76-.04.68-.1C.6-.16.58-.3.66-.36Z"
  ].freeze

  # Tycho, and the ray system that makes it the most recognisable thing on the
  # near side after the seas themselves.
  RAYS = 11

  # Craters, as [ x, y, radius ] in the same unit circle.
  CRATERS = [
    [ -0.16, 0.66, 0.05 ], [ 0.34, -0.66, 0.03 ], [ -0.62, -0.5, 0.028 ],
    [ 0.74, 0.04, 0.022 ], [ -0.06, -0.02, 0.02 ], [ 0.16, 0.8, 0.026 ],
    [ -0.8, 0.12, 0.018 ], [ 0.46, -0.8, 0.018 ], [ -0.34, 0.16, 0.016 ],
    [ 0.06, -0.86, 0.02 ], [ -0.5, -0.16, 0.014 ], [ 0.56, 0.5, 0.017 ]
  ].freeze

  # Angular marks, each drawn in a box twenty across and centred on its own
  # origin. They are ornament and nothing else — the grove says what it means
  # with branches.
  SIGILS = [
    "M0-9L8 0L0 9L-8 0ZM0-3.5a3.5 3.5 0 1 0 .1 0",
    "M-8 6L0-8L8 6ZM-4 1H4",
    "M0-9V9M-6-4L0-9L6-4M-6 4L0 9L6 4",
    "M-8-8L8 8M8-8L-8 8M0-9V9",
    "M0-9a9 9 0 1 0 .1 0M-9 0H9",
    "M-7-7L0 0L7-7M0 0V9M-5 5H5",
    "M0-9L8 0L0 9L-8 0ZM-8 0H8",
    "M-6-9V9M6-9V9M-6-2L6 2",
    "M0-9V9M-7-9H7M-5 5L0 9L5 5",
    "M-8-4L0-9L8-4L8 4L0 9L-8 4Z",
    "M0-9V2M-6 2L0 9L6 2M0-9L-5-4M0-9L5-4",
    "M-7-6L7 6M-7 6L7-6M-9 0H9M0-9V9",
    "M-6-9H6L0 0L6 9H-6",
    "M0-9a9 9 0 1 0 .1 0M-4-4L4 4M4-4L-4 4"
  ].freeze

  # Gear that carries the network rather than living on it. These grow bare
  # forks. Everything else grows a crown, which is the whole grammar of the
  # picture: infrastructure is wood, the things you actually use are leaves.
  STRUCTURAL = [ "internet", "modem", "router", "switch", "access point" ].freeze

  TRUNK_RADIUS = 68.0
  SPREAD       = 2.9 # radians of sky the whole canopy is allowed to fill

  # How many generations of wood grow past the last node. Each one roughly
  # doubles, so five is the difference between a coat rack and a canopy.
  RAMIFY = 8
  ROOTS  = 7

  # How many times longer than wide a piece of wood is. Everything past the
  # network's own limbs takes its length from its own thickness rather than
  # from whatever it grew out of — which is the difference between a twig and
  # a wedge. Getting that backwards made segments a hundred units across and
  # forty long, and they came out as torn paper rather than as branches.
  SLENDER = 11.5

  # Two different questions, both answered by the same number. How much of the
  # network hangs off a limb sets how THICK it is. How much it diverges from the
  # limb it grew out of sets how LONG it is — so a switch carrying most of the
  # traffic stays a short, fat continuation of the trunk, and the twig off to
  # one side reaches. Conflating the two is what turns a tree into a spire.
  RUN_SPAN  = 112.0
  FORK_SPAN = 380.0

  # Where the finished tree has to fit, whatever shape the network turns out to
  # be. Growth happens in the tree's own units and is then scaled into this box
  # in one step, which is why adding an eighth branch cannot push the canopy off
  # the top of the frame.
  FRAME    = { x: 800.0, top: 84.0, width: 1400.0 }.freeze

  # The two ridges behind the tree, as a sum of sines rather than as a hand-drawn
  # bezier — see #ridge_y.
  # Distant range, then the lip of the ground itself. The second one is very
  # nearly flat, because the earth is cut away below it and a cut has an edge.
  RIDGES = [
    { y: 486.0, amp: 40.0, freq: 0.0052, phase: 1.9, jag: 9.0 },
    { y: GROUND, amp: 5.0, freq: 0.0038, phase: 4.4, jag: 0.0 }
  ].freeze
  MAX_ZOOM = 1.7
  STRETCH  = 1.9 # how much wider than tall the fit may pull it. Oaks do this.

  attr_reader :boughs, :rootwood, :twigs, :grain, :foliage, :crowns, :litter, :falling, :ravens, :labels,
              :offerings, :speedtest, :internet

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

  # Cables and dependencies arrive separately because they are drawn in
  # different halves of the picture: a cable is a branch, and a dependency is
  # a root.
  def initialize(nodes: Node.ordered.includes(:services),
                 links: Link.where.not(kind: "logical"),
                 uses:  Link.logical.includes(:to_node))
    @nodes  = nodes.to_a
    @links  = links.to_a
    @uses   = uses.to_a
    @boughs = []
    @crowns = []
    @litter = []
    @falling = []
    @ravens = []
    @labels = []
    @offerings = []
    @limbs  = []
    @twigs   = { limb: [], fine: [], root: [], rootfine: [] }
    @rootwood = []
    @sprigs  = []
    @sprigtips = {}
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
  # The sky's one reading, and it is a size rather than a number. Radius follows
  # the square root of the download, so a gigabit line hangs a visibly larger
  # disc than a DSL one without being twenty times the size of it — and it stays
  # a moon, with nothing printed on it.
  #
  # It sits low and behind the trunk, so the tree is lit from within its own
  # frame rather than by a lamp in the corner. Most of the disc is behind the
  # wood; what you see is what gets past it.
  def orb
    mbps = speedtest&.ok? ? speedtest.down_mbps.to_f : 0.0

    { x: (@base || BASE_X).round(1), y: (GROUND - 118).round(1),
      r: (116 + 62 * Math.sqrt([ mbps, 2000.0 ].min / 900.0)).round(1) }
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
      y = rng.between(BORDER, GROUND - 40)
      { x: rng.between(BORDER, W - BORDER).round(1), y: y.round(1),
        r: rng.between(0.4, 1.5).round(2),
        # Aerial perspective, applied to the sky: stars thin out into the
        # horizon haze rather than stopping at a line.
        o: (rng.between(0.2, 0.85) * (1 - (y / (GROUND + 40)))).round(3),
        delay: rng.between(0, 11).round(1) }
    end
  end

  # A plait, for the frame. Two strands of the same sine a half-period apart,
  # so they cross at fixed points — and at every other crossing the first strand
  # is drawn again on top, which is the whole of what "interlaced" means.
  def self.plait(length, amp, period)
    step  = period / 12.0
    curve = ->(sign) {
      points = (0..(length / step).ceil).map { |i|
        x = [ i * step, length ].min
        "#{x.round(1)} #{(Math.sin(x / period * Math::PI * 2) * amp * sign).round(1)}"
      }
      "M#{points.join('L')}"
    }

    crossings = (0..(length / (period / 2.0)).floor).select(&:even?)

    { under: curve.(-1), over: curve.(1),
      overs: crossings.map { |k|
        mid = k * period / 2.0
        a, b = [ mid - period * 0.16, 0 ].max, [ mid + period * 0.16, length ].min
        points = (0..8).map { |i|
          x = a + (b - a) * i / 8.0
          "#{x.round(1)} #{(Math.sin(x / period * Math::PI * 2) * amp * -1).round(1)}"
        }
        "M#{points.join('L')}"
      } }
  end

  # Where the writing beside the picture hangs from, and how far apart the marks
  # sit down a column.
  SCRIPT_TOP  = GROUND + 74
  SCRIPT_STEP = 32.0

  # How many marks fit above the bottom rail. A mark is nine units tall either
  # side of its own line and is drawn at roughly half size, so it needs a little
  # daylight below it as well as the wood's own edge — a column that ran one
  # mark too far had its last glyph carved into the frame.
  SCRIPT_ROWS = ((H - BORDER - 14 - SCRIPT_TOP) / SCRIPT_STEP).floor + 1

  # Columns of marks, hung from a common line and running down: some two marks
  # long, some five. Ragged column depths are what stop a set of glyphs reading
  # as a caption under the picture and make it read as writing beside one.
  #
  # The draw is truncated rather than narrowed, so the columns that already fit
  # are the columns they always were: the one long column loses its last mark
  # and nothing else moves.
  def self.script(seed, columns)
    rng = Seeded.new(seed)

    columns.times.map do |column|
      marks = rng.between(2, 6.4).to_i.times.map { SIGILS[(rng.next * SIGILS.size).floor] }
      [ column, marks.first(SCRIPT_ROWS) ]
    end
  end

  # Where the trunk actually meets the ground, once the tree has been fitted to
  # the frame. Not BASE_X, which is only where growing started.
  def trunk_x = (@base || BASE_X).round(1)

  # The ground, as numbers rather than as a curve. The distant trees have to
  # stand ON the ridge, and a bezier you can only draw is a bezier you cannot
  # ask the height of — which is how they ended up hovering above it.
  def ridge_y(index, x)
    spec = RIDGES[index]

    spec[:y] +
      Math.sin(x * spec[:freq] + spec[:phase]) * spec[:amp] +
      Math.sin(x * spec[:freq] * 2.7 + spec[:phase] * 2) * spec[:amp] * 0.38 -
      Math.sin(x * spec[:freq] * 7.3 + spec[:phase] * 3).abs * spec[:jag]
  end

  def ridge(index)
    crest = (-40..(W + 40)).step(30).map { |x| "#{x} #{ridge_y(index, x).round(1)}" }

    "M#{crest.join('L')}L#{W + 40} #{H}L-40 #{H}Z"
  end

  # Scenery, and the only thing in the frame that is not a row in the database:
  # a treeline on the ridge so the one tree that means something has a wood to
  # stand in front of. Grown by the same recursion, then flattened into a single
  # hazy stroke — which is what distance does.
  def thicket
    @thicket ||= [].tap do |wood|
      rng = Seeded.new(77_041)

      34.times do
        x = rng.between(BORDER - 10, W - BORDER + 10)
        next if x.between?(FRAME[:x] - 400, FRAME[:x] + 400)

        base   = ridge_y(1, x) + rng.between(0, 14)
        height = rng.between(24, 56)

        far = []
        ramify nil, [ x, base - height ], -Math::PI / 2, 0.9, 4, rng, sink: far
        wood << "M#{xy(x, base)}L#{xy(x + rng.between(-4, 4), base - height)}"
        far.each { |twig| wood << "M#{xy(*twig[:from])}L#{xy(*twig[:to])}" }
      end
    end
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

    # What the network leans on with no cable to say so. Many-to-one, the same
    # shape the canvas draws it in: every machine on the network can point at
    # one Pi-hole, so what matters is how many point at it, not which — and
    # that count is what sets the thickness of its root.
    #
    # Nothing points at the internet in a way worth drawing. A root reaching
    # for the trunk it grew out of says nothing.
    def providers
      @providers ||= @uses.reject { |use| use.to_node.internet? }
                          .group_by(&:to_node)
                          .map { |node, uses|
                            # The link's own label, not Link#caption — caption
                            # falls back to the provider's name, and a root
                            # reading "Router · Router" is a label twice.
                            # How many things lean on it, not how many ways
                            # they lean: one box asking the same router for DNS
                            # and NTP is one dependent, not two.
                            { node: node, weight: uses.map(&:from_node_id).uniq.size,
                              what: uses.filter_map { |use| use.label.presence }.uniq.first }
                          }
                          .sort_by { |provider| [ -provider[:weight], provider[:node].id ] }
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
      tip = [ radius * (kids.empty? ? 0.38 : 0.84), 2.2 ].max

      @limbs << { node: node, from: from, to: to, angle: angle, depth: depth, dead: dead,
                  r0: radius, r1: tip, bow: span * rng.between(-0.2, 0.2),
                  crowned: !STRUCTURAL.include?(node.kind) || kids.empty? }

      # The wood past the last node is placed here too, not at ink time. It is
      # most of the tree's extent, and a fit that measured only the limbs it
      # grew from put the canopy through the top of the frame.
      2.times do
        next if depth <= 1

        along = rng.between(0.58, 0.95)
        ramify node, lerp(from, to, along),
               angle + (rng.next < 0.5 ? -1 : 1) * rng.between(0.45, 0.95),
               (radius + (tip - radius) * along) * 0.3, RAMIFY - 2, rng
      end

      # A limb that already carries child limbs only puts minor wood out of its
      # tip; one that ends here puts its whole crown there.
      ramify node, to, angle, kids.empty? ? tip : tip * 0.34,
             dead ? RAMIFY - 2 : RAMIFY, rng, leafy: !dead

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

        # How much sky a limb gets is not the same question as how much traffic
        # it carries. A tree with neighbours divides the light it can reach;
        # this one has none, so it spreads evenly and the sector is shared out
        # much closer to equally than the load is. Thickness still follows the
        # load exactly — that is the part that is information.
        slice  = sector * (share * 0.4 + 0.6 / kids.size)
        aim    = cursor + slice / 2.0
        cursor += slice

        # Open-grown wood still leaves the trunk at different heights, but far
        # less than a crowded tree does: nothing is racing anything upward.
        along = if kid == trunk
          1.0
        else
          rank = steps.index(kid)
          0.7 + 0.28 * (steps.one? ? 0.6 : rank / (steps.size - 1.0)) + rng.between(-0.03, 0.03)
        end

        # Pull the limb back toward the direction it grew from. A branch that
        # took its whole allotted angle would splay like a hand; a real one
        # leaves the trunk reluctantly and straightens as it goes.
        heading = angle + (aim - angle) * bend + rng.between(-0.04, 0.04)

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
      grown = @limbs + @sprigs
      xs = grown.flat_map { |wood| [ wood[:from][0], wood[:to][0] ] }
      ys = grown.flat_map { |wood| [ wood[:from][1], wood[:to][1] ] }
      return if xs.empty?

      # Measured, not estimated. The twigs are placed before this runs, so the
      # box being fitted is the box the tree actually occupies — which is the
      # only way a tree of any shape ends up inside the frame.
      leaves = 16.0

      @zoom = [ (GROUND - FRAME[:top]) / [ GROUND - ys.min + leaves, 1.0 ].max, MAX_ZOOM ].min
      @wide = [ FRAME[:width] / [ xs.max - xs.min + leaves * 2, 1.0 ].max, @zoom * STRETCH ].min
      # Split the difference between centring the canopy and centring the trunk.
      # A tree hung in a symmetrical frame wants its stem near the middle, but
      # forcing that pushes a lopsided crown off one side.
      spread = FRAME[:x] - ((xs.min + xs.max) / 2 - BASE_X) * @wide
      @base  = spread * 0.55 + FRAME[:x] * 0.45
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
      @sprigs.each { |twig| pen(twig) }
    end

    # One placed twig, scaled into the frame and turned into an outline.
    def pen(twig)
      from   = scaled(twig[:from])
      to     = scaled(twig[:to])
      r0, r1 = twig[:r0] * @zoom, twig[:r1] * @zoom

      (r0 > 2.2 ? @twigs[:limb] : @twigs[:fine]) <<
        wood(from, to, r0, r1, twig[:bow] * @zoom, twig[:reach])
    end

    def ink(placed)
      rng    = Seeded.new(placed[:node].id)
      from   = scaled(placed[:from])
      to     = scaled(placed[:to])
      r0, r1 = placed[:r0] * @zoom, placed[:r1] * @zoom

      bough = limb(from, to, r0, r1, placed[:bow] * @zoom,
                   dead: placed[:dead], angle: placed[:angle], rng: rng,
                   face: placed[:node].id.odd? ? 1.0 : -1.0)

      @boughs << bough
      striate(from, to, r0, r1, rng)
      @tips << { x: to[0], y: to[1], angle: placed[:angle], r: r1 } unless placed[:dead]

      tips = (@sprigtips[placed[:node].id] || []).map { |tip| scaled(tip) }
      size = crown_size(placed[:node])

      if placed[:dead]
        fell(placed[:node], to, size, rng)
        return
      end

      leaf_out(placed[:node], tips, rng) if placed[:crowned]
      shed(placed[:node], to, size, rng)
      crowned(placed[:node], to, size) if placed[:crowned]

      # Tied where the limb says a cord would sit, so the knot is on wood and
      # the cord starts somewhere rather than in the air. Crowned nodes need it
      # to run past the foliage, or the disc hangs inside the leaves.
      offering = hang(placed[:node], bough[:knot],
                      drop: placed[:crowned] ? size * 0.7 : 0.0)
      label(placed[:node], to, placed[:crowned] ? size : r0, offering: offering)
    end

    # One generation of wood, then the same again from each of its ends. Every
    # segment goes into a bucket by generation, and the view draws each bucket
    # as a single path at a single stroke width — so a thousand twigs cost five
    # elements and the line quality stays even, the way an engraving's does.
    # One generation of wood, then the same again from each of its ends.
    #
    # The width carries through. A limb used to end at its tip and a separate
    # system of hairline strokes used to begin there, ten times thinner, and the
    # join was the least convincing thing in the picture. Every twig is now the
    # same kind of object as the trunk — a tapered outline that starts exactly
    # as wide as whatever it grew out of — so the tree narrows continuously from
    # the ground to the last bud, which is the only way a tree ever narrows.
    #
    # Nor does it fork evenly every time. Most of the time one child carries on
    # as the leader, barely turning and barely thinning, and one or two side
    # branches leave at a real angle and much thinner; occasionally the leader is
    # lost and two take over together. That mixture is most of the difference
    # between a tree and a bolt of lightning.
    def ramify(node, from, angle, radius, depth, rng, reach: true, sink: nil, floor: nil, deep: nil, leafy: false)
      return if depth <= 0 || radius < 0.3

      # Density was the whole problem with the canopy. Every fork put out a
      # leader and one or two side branches, at similar angles, and the result
      # filled its own outline evenly — which reads as a single mass rather than
      # as branches, because what makes a tree legible is the sky between them.
      #
      # So: a leader always, a side branch most of the time, a second one
      # rarely, and at wider angles than before. Some are then pruned outright,
      # which is what shade does to the inside of a real crown.
      # Density is the whole question. Filled evenly, a canopy reads as one
      # mass; emptied evenly, it reads as a sea urchin. A tree is neither,
      # because the rule is not uniform: shade kills the twigs on the inside and
      # light grows the ones on the outside. So the branching gets busier the
      # further from the trunk it is, and the pruning only touches the interior.
      outer  = depth <= 4
      forks  =
        if rng.next < 0.3
          [ [ -rng.between(0.36, 0.74), 0.74, 1 ], [ rng.between(0.36, 0.74), 0.74, 1 ] ]
        else
          # Sides alternate down the chain rather than being tossed for. Left
          # or right at random means a limb can throw three branches the same
          # way, and enough of those is the lopsided crown of a tree that spent
          # its life leaning out from under something else.
          sway   = depth.even? ? 1 : -1
          leader = [ [ rng.between(-0.16, 0.16), 0.9, 1 ] ]
          leader << [ sway * rng.between(0.5, 1.2), 0.63, 2 ] if rng.next < (outer ? 0.94 : 0.6)
          leader << [ -sway * rng.between(0.5, 1.2), 0.54, 2 ] if rng.next < (outer ? 0.45 : 0.12)
          leader
        end

      forks.each_with_index do |(lean, narrow, cost), i|
        next if i.positive? && !outer && rng.next < 0.28
        heading = angle + lean + rng.between(-0.1, 0.1)

        # A branch that simply runs out of generations stops at whatever width
        # it had left, and a limb with a blunt square end is the one thing no
        # tree has. The last segment before the recursion stops comes to a
        # point instead.
        last    = depth - cost <= 0
        tip     = [ radius * (last ? 0.16 : narrow), 0.2 ].max

        # Wide variation in internode length is the other half of the air: a
        # canopy where every span is the same length is a lattice.
        len = tip * SLENDER * rng.between(0.66, 1.42)
        to      = [ from[0] + Math.cos(heading) * len, from[1] + Math.sin(heading) * len ]

        # Underground, a fork that would surface is turned back down instead.
        # Negating the heading mirrors it about the horizontal, so the root keeps
        # the direction it was travelling and only loses the ambition.
        # A root that would break the surface is turned back down, and one that
        # would leave the bottom of the picture is turned back up. Negating the
        # heading mirrors it about the horizontal, so it keeps the direction it
        # was travelling and only loses the ambition.
        if (floor && to[1] < floor) || (deep && to[1] > deep)
          heading = -heading
          to = [ from[0] + Math.cos(heading) * len, from[1] + Math.sin(heading) * len ]
        end

        twig = { from: from, to: to, r0: radius, r1: tip,
                 bow: len * rng.between(-0.16, 0.16), reach: reach }

        sink ? (sink << twig) : (@sprigs << twig)
        (@sprigtips[node.id] ||= []) << to if leafy && depth <= 2

        ramify node, to, heading, tip, depth - cost, rng,
               reach: reach, sink: sink, floor: floor, deep: deep, leafy: leafy
      end
    end

    # A twig is the same object as a trunk, only thinner: a tapered outline with
    # the same phototropic bow in it.
    def wood(from, to, r0, r1, bow, reach)
      dx, dy = to[0] - from[0], to[1] - from[1]
      len    = Math.hypot(dx, dy).nonzero? || 1.0
      nx, ny = -dy / len, dx / len

      bend = (ny.negative? ? 1 : -1) * len * 0.2 * ny.abs
      bow += reach ? bend : -bend

      taper(from, to, r0, r1, bow, nx, ny)
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
    # The moon is behind the tree, so the wood is a silhouette and there is no
    # lit side to paint: a backlit cylinder is dark all the way across and
    # bright only at the edge the light gets past. That edge is the one sliver
    # left, and how bright it burns depends on two things — how side-on the limb
    # is to the light, and how near the light it stands. Both are one dot
    # product and one distance, and together they are the whole of the lighting.
    def limb(from, to, r0, r1, bow, dead:, angle:, rng:, reach: true, face: nil)
      dx, dy = to[0] - from[0], to[1] - from[1]
      len    = Math.hypot(dx, dy).nonzero? || 1.0
      nx, ny = -dy / len, dx / len

      # One light, in a place rather than a direction: a limb to the left of the
      # trunk is lit from its right and one to the right from its left, which is
      # what backlighting looks like and what a fixed vector cannot say.
      lx = orb[:x] - (from[0] + to[0]) / 2
      ly = orb[:y] - (from[1] + to[1]) / 2
      ll = Math.hypot(lx, ly).nonzero? || 1.0
      facing = nx * (lx / ll) + ny * (ly / ll)
      side   = facing.negative? ? -1.0 : 1.0

      # Phototropism. A limb heading sideways arcs upward along its length, and
      # one heading straight up does not — the strength of the bend is exactly
      # how horizontal the limb is. It is the difference between a tree that
      # grew and a tree drawn with a ruler, and it costs one term.
      bow -= (ny.negative? ? -1 : 1) * len * 0.16 * ny.abs if reach

      near = 1.0 / (1.0 + ll / 240.0)

      # Where a cord would sit if you looped it over this limb. It has to be on
      # the wood's own surface: offset from the limb's axis by the radius at
      # that point, along the normal, and taken from the curve rather than the
      # chord — a quadratic leaves its chord by 2t(1-t) of the control offset.
      # Guessed at as "the tip, shifted sideways a bit" it landed in open air,
      # because a limb tapers to nothing at its tip and does not run vertically
      # to begin with.
      #
      # Under the branch when it has any run to it, which is the only place you
      # can hang something; on the outward face when it is upright, where a
      # cord would sit round a trunk.
      along = 0.78
      grip  = r0 + (r1 - r0) * along
      kx    = from[0] + dx * along + nx * bow * 2 * along * (1 - along)
      ky    = from[1] + dy * along + ny * bow * 2 * along * (1 - along)
      # An upright limb has a horizontal normal, so the choice is which side of
      # the trunk rather than over or under. Left to geometry alone the whole
      # chain up the trunk picks the same side and hangs in one straight line,
      # so the caller gets to alternate them.
      #
      # Its own name, and not `side`: that one is which edge the moon gets past,
      # and reusing it put every rim highlight on whichever side a cord would
      # hang from instead — a sliver of moonlight painted down the shadow side.
      knotted = if ny.abs > 0.4
                  ny.positive? ? 1.0 : -1.0
      else
                  (face || (kx >= (@base || BASE_X) ? 1.0 : -1.0)) * (nx.negative? ? -1.0 : 1.0)
      end

      { body:  taper(from, to, r0, r1, bow, nx, ny),
        knot:  [ kx + nx * grip * knotted, ky + ny * grip * knotted ],
        rim:   taper(shift(from, nx, ny, side * r0 * 0.82), shift(to, nx, ny, side * r1 * 0.82),
                     r0 * 0.17, r1 * 0.17, bow, nx, ny),
        glare: (facing.abs * near).round(3),
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
      rest = [ (spot[0] + rng.between(-40, 40)).clamp(BORDER + 60, W - BORDER - 60), GROUND + rng.between(2, 14) ]

      @crowns << { node: node, state: "fallen", x: rest[0].round(1), y: rest[1].round(1), r: size }

      (size * 0.9).to_i.times do
        @foliage << { d: leaf(rest[0] + rng.between(-size, size),
                              rest[1] + rng.between(-size * 0.3, size * 0.34),
                              rng.between(2.4, 4.6) * @zoom, rng.between(0, Math::PI)),
                      tone: "dead" }
      end

      # It came down with the crown. Beside it rather than under it, so it is
      # not one more thing lost in the pile of dead leaves.
      offering = hang(node, rest, state: "fallen",
                      aside: rng.between(-size * 0.5, size * 0.5), drop: rng.between(2, 10))
      label(node, rest, size * 0.5, offering: offering)
      @litter.concat scatter(spot[0], 16, rng)
    end

    def scatter(x, count, rng)
      Array.new(count) {
        near = rng.next # 0 is far up the slope, 1 is at the viewer's feet
        { x: (x + rng.between(-110, 110)).clamp(BORDER + 20, W - BORDER - 20).round(1),
          y: (GROUND - 10 + near * 22).round(1),
          r: (1.3 + near * 2.2).round(2),
          tilt: rng.between(0, 180).round }
      }
    end

    # What a Norse label actually was. The Bryggen finds are hundreds of small
    # rune-sticks, and a good many of them are somebody saying which of it is
    # theirs — a tag tied to the thing it names. Hung in the tree because that
    # is what a sacred grove had in it, and because a thing on a cord swings a
    # little behind the branch it hangs from.
    #
    # Motion is the one channel this picture has spare. It has one light and
    # two tones and no room for a third, but nothing in it moves except the
    # sway — so an offering can say "there is something here to point at"
    # without spending a colour or a second lamp on saying it.
    #
    # Gear that carries the network gets a ring and everything else gets a
    # stick, which is the grammar the wood already uses: infrastructure is one
    # kind of thing, what you actually use is another. Status stays in shape
    # rather than colour — a living node's offering hangs, a dead one's has
    # come down and is lying in the litter with its leaves.
    def hang(node, spot, state: "hung", drop: 0.0, aside: 0.0)
      # The node's own seed, and nothing else's. Handed the caller's rng, this
      # was seeded by whatever had already drawn from it -- so a NAS changed its
      # mark when one of its services went down, because `shed` consumes draws
      # in proportion to the dead ones, and a provider changed its mark when a
      # heavier one pushed it into a different root slot. A tag you learn a node
      # by cannot move when nothing about the node moved.
      #
      # It follows that a node appearing twice -- once in the canopy, once as a
      # root others lean on -- wears the same mark in both places, which is the
      # entire point of having a mark.
      # Two streams, because they answer to different things. The tag itself --
      # the shape of the wood and the mark burned into it -- is the node's
      # identity and must not shift for any reason at all; where it hangs is
      # incidental. Sharing one stream, a hung offering drew its cord length
      # first and a buried one did not, so the same node came out wearing two
      # different marks.
      mark = Seeded.new(node.id * 7_919)
      rng  = Seeded.new(node.id * 104_729)
      size = 18.0 * @zoom
      hung = state == "hung"

      # It rests under its own knot. A thing on a cord has nothing holding it
      # out to one side, so the cord is vertical and the disc is directly below
      # where it is tied — the swing is the wind, and the wind is not a
      # standing condition.
      #
      # What moves instead is the knot. A cord looped over a limb sits on the
      # wood's surface rather than running out of the middle of it, so the tie
      # goes to the edge and the disc hangs down past the side of the branch
      # into open air. Hanging it off the axis was the first attempt at this
      # and it was a cord held out sideways by nothing; hanging it off the axis
      # of a trunk-chain node was the second, and put four discs in a line down
      # the trunk like buttons on a coat. The edge of the wood is the one place
      # that is both true and not camouflage.
      # `drop` lengthens the cord; it does not move the knot. Letting it do both
      # walked the tie point down off the branch and left a crowned node's cord
      # starting in mid-air below the wood it was supposed to be tied to.
      at   = hung ? spot : [ spot[0] + aside, spot[1] + drop ]
      # Nothing to hang from once it has come down, so it lies centred instead.
      cord = hung ? rng.between(15, 46) * @zoom : 0.0
      top  = hung ? drop + cord : -size

      # The same light as everything else. One orb, in a place rather than a
      # direction, so a token near it takes more rim than one out at the edge.
      near = 1.0 / (1.0 + Math.hypot(orb[:x] - at[0], orb[:y] - at[1]) / 240.0)

      offering = { node: node, state: state,
                   x: at[0].round(1), y: at[1].round(1),
                   r: size.round(2), cord: cord.round(2), top: top.round(2),
                   disc: slice(size, top, mark),
                   marks: bindrune(size, top, mark),
                   beads: (beads(top, rng) if hung),
                   # Metal catches the moon, so how brightly depends on how
                   # near it hangs to it. Same light as the limbs, spent on the
                   # whole token rather than on one edge of it: a lit rim needs
                   # a shape big enough to have sides, and this has not.
                   glare: (0.62 + 0.38 * near).round(3),
                   # A pendulum's period goes with the square root of its
                   # length, so the long ones swing slower than the short ones
                   # on their own and no two of them keep time. Guessing the
                   # durations at random would have looked like this and been a
                   # coincidence; taking them from the cord makes it the same
                   # fact twice, which is what stops it reading as decoration.
                   dur: (6.6 * Math.sqrt(cord / (26.0 * @zoom)) + rng.between(-0.4, 0.4))
                          .clamp(4.5, 13.0).round(2),
                   delay: rng.between(0, 4).round(2),
                   tilt: state == "hung" ? 0 : rng.between(-74, 74).round }

      @offerings << offering
      offering
    end

    # A slice cut across a branch, which is what the wood these are made of
    # actually is. Built as a closed curve through jittered points rather than
    # an ellipse, because nothing sawn off a tree comes out round — and a
    # perfect ellipse is most of what made the first attempt look stamped out
    # rather than cut.
    def slice(size, top, rng)
      rx, ry = size * 0.82, size
      cy     = top + ry

      points = 12.times.map { |i|
        angle = i * Math::PI * 2 / 12
        wobble = 1.0 + rng.between(-0.075, 0.075)
        [ Math.cos(angle) * rx * wobble, cy + Math.sin(angle) * ry * wobble ]
      }

      # Through the midpoints, with each point as the control — the standard way
      # to get a closed curve that actually passes smoothly rather than a
      # polygon with the corners knocked off.
      mid  = ->(a, b) { [ (a[0] + b[0]) / 2.0, (a[1] + b[1]) / 2.0 ] }
      path = +"M#{xy(*mid.(points[-1], points[0]))}"

      points.each_with_index do |point, i|
        path << "Q#{xy(*point)} #{xy(*mid.(point, points[(i + 1) % points.size]))}"
      end

      path << "Z"
    end

    # A bind-rune: several runes sharing one stave, which is how a Norse
    # personal mark was made. Off the node's own seed, so it is the same mark
    # every time and no two nodes wear the same one — which is how you come to
    # know one without reading it.
    #
    # Runes are a stave and diagonals off it. Horizontal nicks, which is what
    # this was before, are the one thing runic writing does not have: cut
    # across the grain they would split the wood, and on screen they read as
    # ruled lines rather than as writing.
    def bindrune(size, top, rng)
      cy   = top + size
      # Well inside the disc. A rune crowded to the edge of the wood is what
      # made these read as a stamped token rather than a burned one — the
      # margin of bare wood around the mark is most of what says "burned in".
      half = size * 0.46
      path = +"M#{xy(0, cy - half)}L#{xy(0, cy + half)}"

      (2 + (rng.next * 2.4).floor).times do
        y    = cy + rng.between(-0.72, 0.72) * half
        arm  = rng.next < 0.5 ? -1 : 1
        run  = rng.between(0.22, 0.36) * size
        rise = run * rng.between(0.55, 1.05)

        path << if rng.next < 0.36
          # A chevron meeting the stave, which is the shape most of them are.
          "M#{xy(arm * run, y - rise)}L#{xy(0, y)}L#{xy(arm * run, y + rise)}"
        else
          "M#{xy(0, y)}L#{xy(arm * run, y - rise)}"
        end
      end

      path
    end

    # The cord is strung rather than plain. It is four or five beads at this
    # size, which is enough to say "threaded" and not enough to become a rash
    # of dots.
    def beads(top, rng)
      count = 4 + (rng.next * 2).floor

      (1...count).map { |i|
        t = i.to_f / count
        (top * t).round(2)
      }
    end

    # Hidden until you point at it. The scene is wordless at rest, and the hit
    # target is what the pointer finds — never the text, which would mean
    # hovering something invisible.
    # Most labels are the node's own name, because most of them hang on the
    # thing itself. A root is the exception: the crown already says what the
    # box is called, so the root says what it is *for*.
    #
    # The hit target has to reach whatever is hanging there. What you can see
    # and what you can point at being different places is worse than having
    # nothing to see at all — you would learn that pointing does not work.
    def label(node, spot, radius, text: node.name, buried: false, offering: nil, raven: nil)
      # The name belongs to the thing you can see, so the ring, the target and
      # the text all sit on the marker rather than on the wood it hangs from.
      # Left on the limb, the ring drew itself a cord's length above whatever
      # the cursor was actually over -- up around a crown, while the token the
      # pointer had found swung on unmarked below it.
      if offering
        spot   = [ offering[:x], offering[:y] + offering[:top] + offering[:r] ]
        radius = offering[:r]
      elsif raven
        # A bird stands on its feet and fills the air above them.
        spot   = [ raven[:x], raven[:y] - 14 * raven[:scale] ]
        radius = 30 * raven[:scale]
      end

      away = spot[0] < BASE_X ? -1 : 1

      # The offering rides along with the name rather than being reached for by
      # it. Widening this disc to cover a token on a long cord made the discs
      # of neighbouring nodes overlap, and an overlapping hit target answers
      # with whichever name happens to be drawn last.
      @labels << { node: node, text: text, buried: buried, offering: offering, raven: raven,
                   state: node.rollup_status,
                   x: spot[0].round(1), y: spot[1].round(1),
                   # What the highlight encircles and what the pointer can find
                   # are different questions: the ring hugs the marker, and the
                   # target stays generous enough to hit.
                   ring: (radius * 1.5).round(1),
                   hit: [ radius * 1.1, 26.0 ].max.round(1),
                   tx: (spot[0] + away * ([ radius, 26.0 ].max + 8)).round(1),
                   ty: (spot[1] - 4).round(1),
                   anchor: away.negative? ? "end" : "start" }
    end

    # The trunk does not stop at the ground; it splays into it and keeps
    # dividing — and the plate is where the half of the network nobody draws
    # goes. A logical link is a real dependency with no cable to carry it: the
    # router asking Pi-hole for DNS travels over the same ethernet as
    # everything else, so it is not a branch. It is what the tree is standing
    # in. Thickness follows load down here exactly as it does up in the
    # canopy, counted in the nodes that lean on the thing the root reaches for.
    #
    # Nine limbs either way, because the plate has to read as a plate on a
    # network with no logical links at all. Providers claim slots from the
    # middle out — the heaviest becomes the taproot — and the rest of the
    # slots stay the invention they always were.
    def flare
      # Every root draws from its own seed rather than from one running
      # sequence, so a dependency appearing in the middle of the plate cannot
      # reshuffle the roots either side of it. Same rule as the limbs, which
      # seed from the node they carry.
      # Nine roots make a plate; a network that leans on more things than that
      # grows the extra ones rather than losing them. Capping it at nine dropped
      # the tenth dependency and everything after it with no mark of any kind --
      # and a picture whose whole claim is that nothing in it is new information
      # cannot quietly hold less of it than the rows do.
      slots  = [ 9, providers.size ].max
      across = ->(i) { slots > 1 ? -1.0 + 2.0 * i / (slots - 1) : 0.0 }
      order  = slots.times.sort_by { |i| [ across.(i).abs, across.(i) ] }
      taken  = order.zip(providers).to_h
      most   = providers.first&.fetch(:weight).to_f

      slots.times do |i|
        rng      = Seeded.new(4_051 + i * 97)
        spread   = across.(i)
        provider = taken[i]

        # Leonardo, pointed downward: a root is as thick as the share of the
        # network that leans on what it reaches for, and it reaches as far.
        share = provider ? Math.sqrt(provider[:weight] / most) : 0.0
        fat   = provider ? 0.85 + 0.55 * share : 1.0
        far   = provider ? 1.0 + 0.45 * share : 1.0
        dead  = provider ? provider[:node].status_down? : false

        from   = [ @base + spread * 7, GROUND - 8 * @zoom ]
        reach  = rng.between(110, 260) * @wide * far
        drop   = rng.between(70, 165) * @zoom * far

        # The middle ones dive rather than spread; the outer ones do the
        # opposite. A root plate is both, and drawing only the fan makes the
        # tree look like it is standing on a doily.
        to = [ @base + spread * reach * (0.35 + 0.65 * spread.abs), GROUND + drop * (1.4 - spread.abs) ]
        aim = Math.atan2(to[1] - from[1], to[0] - from[0])

        # A root that ends in a blunt stub and then sprouts hair is the join the
        # branches used to have. It ends as thick as what carries on from it.
        buttress = TRUNK_RADIUS * (0.15 - 0.03 * spread.abs) * @zoom * fat

        # The root carries the node it reaches for, or nothing when the slot is
        # one of the invented ones holding the plate up.
        @rootwood << limb(from, to, TRUNK_RADIUS * (0.34 - 0.06 * spread.abs) * @zoom * fat,
                          buttress, rng.between(10, 26) * (spread.negative? ? -1 : 1),
                          dead: dead, angle: aim, rng: rng, reach: false)
                       .merge(node: provider&.fetch(:node))

        # A dependency that is down is rot, and rot is a root that stops. The
        # same thing a dead limb does above the line, said underground.
        roots = []
        ramify nil, to, aim, buttress, dead ? ROOTS - 3 : ROOTS, rng,
               reach: false, sink: roots, floor: GROUND + 10, deep: H - BORDER - 34
        roots.each { |root| (root[:r0] > 2.2 ? @twigs[:root] : @twigs[:rootfine]) <<
          wood(root[:from], root[:to], root[:r0], root[:r1], root[:bow], false) }

        # The crown already says what the box is called. The root says what the
        # network is using it for, which is the part the canopy cannot carry.
        next if provider.nil?

        # Down where the dependency is. A thing put into the ground rather than
        # hung in the air, which is the other half of where Norse offerings
        # actually turn up.
        offering = hang(provider[:node], to, state: "buried",
                        aside: rng.between(-16, 16), drop: rng.between(8, 20))

        label provider[:node], to, buttress, buried: true, offering: offering,
              text: [ provider[:node].name, provider[:what] ].compact.join(" · ")
      end
    end

    def perch
      @nodes.reject { |node| @rooted[node.id] }.each do |node|
        rng = Seeded.new(node.id * 31)

        spots = perches

        if node.status_down? || spots.empty?
          x = (@base + (rng.next < 0.5 ? -1 : 1) * rng.between(330, 520)).clamp(BORDER + 90, W - BORDER - 90)
          y = GROUND + rng.between(1, 9)

          raven = { node: node, pose: "hunting", scale: 1.05, x: x.round(1), y: y.round(1),
                    flip: rng.next < 0.5 }

          @ravens << raven
          label(node, [ x, y - 26 ], 26, raven: raven)
        else
          spot = spots[(rng.next * spots.size).floor]

          # No offering on a raven. The bird is already the most conspicuous
          # thing in the picture and it already marks exactly one node, so a
          # tag hung beside it is a second marker for something that has one —
          # and hung on the twig the bird is gripping, it read as a third
          # object belonging to neither.
          raven = { node: node, pose: "perched", scale: 0.62,
                    x: spot[:x].round(1), y: (spot[:y] + spot[:r] * 0.5).round(1),
                    flip: Math.cos(spot[:angle]).negative? }

          @ravens << raven
          label(node, [ spot[:x], spot[:y] - 26 ], 26, raven: raven)
        end
      end
    end

    def shift(point, nx, ny, by) = [ point[0] + nx * by, point[1] + ny * by ]
    def xy(x, y) = "#{x.round(1)} #{y.round(1)}"
end
