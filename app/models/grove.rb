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
  # How far the hung offerings are allowed to shrink with the tree. Below this
  # the disc is smaller than the rune burned into it needs to be legible, and
  # the whole point of hanging one is that you can see it from across the frame.
  ORNAMENT_FLOOR = 0.65

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
  # Everything the picture is drawn from, as one short string. Drawing it costs
  # sixty-odd milliseconds on a small network and four hundred on a large one,
  # and the answer only changes when one of these does -- so the scene is
  # cached against this and the cost is paid once per change rather than once
  # per look.
  #
  # Values rather than `updated_at`, deliberately. A probe stamps every node it
  # visits whether or not anything moved, so keying on timestamps would redraw
  # the whole tree every sweep to arrive at exactly the same picture. These are
  # the columns the drawing actually reads: what a node is and how it is, which
  # services are inside it and how they are, what is cabled to what, the last
  # reading the moon is sized by, and which way up the theme is -- because a
  # light theme hangs a sun where the moon was, and that is markup.
  def self.stamp
    Digest::SHA256.hexdigest([
      Node.order(:id).pluck(:id, :position, :name, :kind, :status),
      Service.order(:id).pluck(:id, :node_id, :status),
      Link.order(:id).pluck(:id, :kind, :label, :from_node_id, :to_node_id),
      Speedtest.latest&.id,
      Omarchy.mode
    ].inspect)
  end

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
    @roosts = []
    @stride = 0
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

  # The drawing, in the order it happens: the rows become a tree, the tree is
  # grown and then sized to the paper, the wood and the leaves are inked, and
  # everything hung on it rather than grown by it comes last. One object still —
  # these are its chapters, not its collaborators.
  include Graph, Growth, Wood, Foliage, Ornament, Roots

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

    def shift(point, nx, ny, by) = [ point[0] + nx * by, point[1] + ny * by ]

    def xy(x, y) = "#{x.round(1)} #{y.round(1)}"
end
