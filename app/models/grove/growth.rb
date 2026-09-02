class Grove
  # Where everything goes, and then the same tree sized to the paper.
  #
  # Growing happens in the tree's own units and is scaled into the frame in one
  # step afterwards, which is why adding an eighth branch cannot push the
  # canopy off the top of the picture.
  module Growth
    private
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
  end
end
