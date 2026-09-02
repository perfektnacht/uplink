class Grove
  # Ink. Every limb is a tapered outline rather than a stroke, so it can be
  # wide where it leaves the ground and thin where it ends — and the thousands
  # of twigs past the network's own forks concatenate into two path elements.
  module Wood
    private
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

        # Somewhere for a bird to stand that is not one of the dozen limb ends.
        # A four-node network has four of those, and two ravens sent to the same
        # one land on the same pixel. Every seventeenth twig of a grippable size
        # is plenty and keeps the list short.
        @stride += 1
        @roosts << { x: to[0], y: to[1], angle: 0.0, r: r1 } if r1.between?(2.4, 7.0) && (@stride % 17).zero?
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
      #
      # The width carries through: every twig is the same kind of object as the
      # trunk, a tapered outline that starts exactly as wide as whatever it grew
      # out of, so the tree narrows continuously from the ground to the last bud.
      # Which is the only way a tree ever narrows.
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
  end
end
