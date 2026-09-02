class Grove
  # What is hung on the tree rather than grown by it. A tag on a cord naming
  # each node, and the names themselves — which are wordless until you point
  # at one, so the tag is what says there is anything to point at.
  module Ornament
    private
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
        # An offering shrinks with the tree it hangs in, down to a point. Past
        # that it is no longer a rune you could read, it is a speck -- and a mark
        # nobody can make out is not a mark. So the ornament keeps its own scale
        # with a floor under it: a thirteen-node network fits at about 0.42, which
        # put the discs at seven units and the marks past reading.
        #
        # The cord takes the same scale, or a floored disc would hang off a
        # hairline shorter than itself.
        scale = [ @zoom, ORNAMENT_FLOOR ].max
        size  = ornament
        hung  = state == "hung"

        # It rests under its own knot: a thing on a cord has nothing holding it
        # out to one side, so the cord is vertical and the disc hangs directly
        # below the tie. The swing is the wind, and the wind is not a standing
        # condition.
        #
        # What moves instead is the knot, which sits on the wood's surface rather
        # than running out of the middle of it — the edge of the branch is the one
        # place that is both true and not camouflage.
        #
        # `drop` lengthens the cord; it does not move the knot.
        at   = hung ? spot : [ spot[0] + aside, spot[1] + drop ]
        # Nothing to hang from once it has come down, so it lies centred instead.
        cord = hung ? rng.between(15, 46) * scale : 0.0
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

      # How big a hung or buried disc is. Asked for in two places -- when one is
      # drawn, and when the plate works out whether two of them would land on top
      # of each other -- so it is worked out in one.
      def ornament = 18.0 * [ @zoom, ORNAMENT_FLOOR ].max

      # A slice cut across a branch, which is what the wood these are made of
      # actually is. A closed curve through jittered points rather than an
      # ellipse, because nothing sawn off a tree comes out round — and a perfect
      # one reads as stamped out rather than cut.
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
  end
end
