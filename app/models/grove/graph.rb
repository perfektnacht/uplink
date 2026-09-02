class Grove
  # The rows, before they are a tree. A LAN is very nearly a tree already;
  # this is the walk that makes it exactly one, plus the two counts the drawing
  # takes its thicknesses from.
  module Graph
    private
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
  end
end
