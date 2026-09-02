class Grove
  # Leaves, and what happens to them. Hung on the twigs that exist rather than
  # painted as a mass over them, so the canopy has the shape the wood gave it —
  # and dropped on the floor when the thing they belong to stops answering.
  module Foliage
    private
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
  end
end
