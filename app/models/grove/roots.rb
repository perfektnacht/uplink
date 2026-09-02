class Grove
  # The half of the picture below the ground line, and the birds that never
  # landed in the tree at all: the root plate the logical links are drawn as,
  # and the ravens for nodes with no cable to grow a branch from.
  module Roots
    private
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
        @buried = []
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

          # Down where the dependency is: a thing put into the ground rather than
          # hung in the air, which is the other half of where Norse offerings
          # actually turn up.
          #
          # Along its own root rather than always at the tip. The roots nearest
          # the trunk are the closest together and the heaviest dependencies are
          # the ones sent there, so two discs landed six units apart with a
          # radius of twelve -- one on top of the other, and one of the two nodes
          # with nothing you could point at. Each one now walks out along its own
          # root until it is clear of the ones already down there.
          aside = rng.between(-16, 16)
          down  = rng.between(8, 20)
          step  = ornament * 2.5

          spot = 8.times.map { |out|
            [ to[0] + Math.cos(aim) * step * out + aside, to[1] + Math.sin(aim) * step * out + down ]
          }.find { |cx, cy|
            cy < H - BORDER - ornament && cx.between?(BORDER + ornament, W - BORDER - ornament) &&
              @buried.none? { |bx, by| Math.hypot(bx - cx, by - cy) < ornament * 2.4 }
          } || [ to[0] + aside, to[1] + down ]

          @buried << spot
          offering = hang(provider[:node], spot, state: "buried")

          label provider[:node], to, buttress, buried: true, offering: offering,
                text: [ provider[:node].name, provider[:what] ].compact.join(" · ")
        end
      end

      # Where a raven can stand and still be seen. Thin tips, out where there is
      # air around them, and not one another's branch.
      #
      # Any thin tip would do if there were one bird. With two, the second landed
      # in the fork of the trunk with the first almost above it -- and a bird
      # tucked into the trunk reads as part of the wood rather than as a visitor
      # on it, which is the one thing a raven is for.
      def perches(taken)
        thin  = (@tips + @roosts).select { |tip| tip[:r] < 16 }
        thin  = @tips if thin.none?
        # A tree with every limb dead has no live tip to stand on. There is still
        # wood, so there is still somewhere to land: a bird that is up must not be
        # left with nowhere, because the only other place to put it says down.
        thin  = @boughs.map { |bough|
          { x: bough[:joint][0], y: bough[:joint][1], r: bough[:joint][2], angle: 0.0 }
        } if thin.none?
        clear = thin.select { |tip| (tip[:x] - @base).abs > 70 }
        clear = thin if clear.none?

        alone = clear.reject { |tip| near_any?(taken, tip[:x], tip[:y], 130) }
        return alone if alone.any?

        # Nowhere with that much air around it, so the furthest from the birds
        # already placed. A throw of the dice here can land two on one twig.
        [ clear.max_by { |tip| taken.map { |spot| Math.hypot(spot[0] - tip[:x], spot[1] - tip[:y]) }.min || 0.0 } ].compact
      end

      def near_any?(taken, x, y, within)
        taken.any? { |spot| Math.hypot(spot[0] - x, spot[1] - y) < within }
      end

      def perch
        taken = []

        @nodes.reject { |node| @rooted[node.id] }.each do |node|
          rng = Seeded.new(node.id * 31)

          spots = perches(taken)

          # A bird on the ground is how this picture says the node is down, so only
          # a node that is down may be put there. Having nowhere to perch is a
          # fact about the tree, and drawing it on the node was the picture
          # telling you a thing that was not so.
          if node.status_down?
            # Hunting, on the ground, a long way from the tree. Several throws and
            # the one furthest from the birds already down there, so two of them
            # do not end up working the same patch of grass.
            x, y = 4.times.map {
              [ (@base + (rng.next < 0.5 ? -1 : 1) * rng.between(330, 520)).clamp(BORDER + 90, W - BORDER - 90),
                GROUND + rng.between(1, 9) ]
            }.max_by { |cx, cy| taken.map { |spot| Math.hypot(spot[0] - cx, spot[1] - cy) }.min || Float::INFINITY }

            raven = { node: node, pose: "hunting", scale: 1.05, x: x.round(1), y: y.round(1),
                      flip: rng.next < 0.5 }

            @ravens << raven
            taken << [ x, y ]
            label(node, [ x, y - 26 ], 26, raven: raven)
          elsif spots.any?
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
            taken << [ raven[:x], raven[:y] ]
            label(node, [ spot[:x], spot[:y] - 26 ], 26, raven: raven)
          end
        end
      end
  end
end
