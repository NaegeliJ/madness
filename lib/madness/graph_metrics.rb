module Madness
  class Graph
    # Pure-Ruby graph metrics over a directed adjacency map
    # (node id => array of successor ids). Structural metrics (degree,
    # components, articulation points, bridges) are exact; the centralities
    # follow NetworkX conventions closely enough for visual encoding.
    class Metrics
      attr_reader :nodes, :adjacency

      def initialize(nodes, adjacency)
        @nodes = nodes
        @adjacency = adjacency
      end

      def edges
        @edges ||= nodes.flat_map { |src| adjacency[src].map { |dst| [src, dst] } }
      end

      def edge_count
        edges.size
      end

      # Total (in + out) degree, matching NetworkX DiGraph#degree.
      def degree
        @degree ||= begin
          result = {}
          nodes.each { |node| result[node] = 0 }
          adjacency.each do |src, targets|
            result[src] += targets.size
            targets.each { |dst| result[dst] += 1 }
          end
          result
        end
      end

      def undirected
        @undirected ||= begin
          adj = {}
          nodes.each { |node| adj[node] = [] }
          adjacency.each do |src, targets|
            targets.each do |dst|
              adj[src] << dst
              adj[dst] << src
            end
          end
          adj.each_value(&:uniq!)
          adj
        end
      end

      def components
        @components ||= begin
          seen = {}
          result = []
          nodes.each do |start|
            next if seen[start]

            queue = [start]
            seen[start] = true
            group = []
            until queue.empty?
              node = queue.shift
              group << node
              undirected[node].each do |neighbor|
                next if seen[neighbor]

                seen[neighbor] = true
                queue << neighbor
              end
            end
            result << group
          end
          result
        end
      end

      def component_count
        components.size
      end

      def connected?
        nodes.any? && component_count == 1
      end

      def articulation_points
        biconnectivity[:articulation_points]
      end

      def bridges
        biconnectivity[:bridges]
      end

      # Iterative Tarjan DFS over the undirected graph, yielding both
      # articulation points and bridges in a single pass.
      def biconnectivity
        @biconnectivity ||= begin
          disc = {}
          low = {}
          parent = {}
          articulation = {}
          bridges = []
          timer = 0

          nodes.each do |start|
            next if disc.key?(start)

            parent[start] = nil
            root_children = 0
            stack = [[start, 0]]

            until stack.empty?
              node, index = stack.last

              if index.zero?
                timer += 1
                disc[node] = low[node] = timer
              end

              neighbors = undirected[node]
              if index < neighbors.size
                stack.last[1] += 1
                neighbor = neighbors[index]

                if !disc.key?(neighbor)
                  parent[neighbor] = node
                  root_children += 1 if node == start
                  stack << [neighbor, 0]
                elsif neighbor != parent[node]
                  low[node] = [low[node], disc[neighbor]].min
                end
              else
                stack.pop
                up = parent[node]
                next unless up

                low[up] = [low[up], low[node]].min
                bridges << [up, node] if low[node] > disc[up]
                articulation[up] = true if parent[up] && low[node] >= disc[up]
              end
            end

            articulation[start] = true if root_children > 1
          end

          { articulation_points: articulation.keys, bridges: bridges }
        end
      end

      # Brandes' algorithm on the directed graph, normalized like NetworkX
      # (1 / ((n-1)(n-2)) for directed graphs).
      def betweenness
        @betweenness ||= begin
          centrality = {}
          nodes.each { |node| centrality[node] = 0.0 }

          nodes.each do |source|
            stack = []
            predecessors = Hash.new { |hash, key| hash[key] = [] }
            sigma = Hash.new(0.0)
            sigma[source] = 1.0
            distance = Hash.new(-1)
            distance[source] = 0
            queue = [source]

            until queue.empty?
              v = queue.shift
              stack << v
              adjacency[v].each do |w|
                if distance[w].negative?
                  distance[w] = distance[v] + 1
                  queue << w
                end
                if distance[w] == distance[v] + 1
                  sigma[w] += sigma[v]
                  predecessors[w] << v
                end
              end
            end

            delta = Hash.new(0.0)
            until stack.empty?
              w = stack.pop
              predecessors[w].each do |v|
                delta[v] += (sigma[v] / sigma[w]) * (1.0 + delta[w])
              end
              centrality[w] += delta[w] if w != source
            end
          end

          size = nodes.size
          if size > 2
            scale = 1.0 / ((size - 1) * (size - 2))
            centrality.each_key { |key| centrality[key] *= scale }
          end
          centrality
        end
      end

      # Incoming-distance closeness with the Wasserman-Faust improvement,
      # matching NetworkX defaults on a directed graph.
      def closeness
        @closeness ||= begin
          size = nodes.size
          result = {}
          nodes.each do |target|
            distance = { target => 0 }
            queue = [target]
            until queue.empty?
              v = queue.shift
              reverse_adjacency[v].each do |w|
                next if distance.key?(w)

                distance[w] = distance[v] + 1
                queue << w
              end
            end

            total = distance.values.sum
            reachable = distance.size
            result[target] =
              if total.positive? && size > 1
                ((reachable - 1).to_f / total) * ((reachable - 1).to_f / (size - 1))
              else
                0.0
              end
          end
          result
        end
      end

      # Eigenvector centrality via power iteration (distributing to
      # successors, as NetworkX does for directed graphs).
      def eigenvector(max_iter: 100, tol: 1.0e-6)
        @eigenvector ||= begin
          size = nodes.size
          if size.zero?
            {}
          else
            x = {}
            nodes.each { |node| x[node] = 1.0 / size }

            max_iter.times do
              previous = x
              x = {}
              nodes.each { |node| x[node] = previous[node] }
              adjacency.each do |src, targets|
                targets.each { |dst| x[dst] += previous[src] }
              end

              norm = Math.sqrt(x.values.sum { |value| value * value })
              norm = 1.0 if norm.zero?
              x.each_key { |key| x[key] /= norm }

              break if nodes.sum { |node| (x[node] - previous[node]).abs } < size * tol
            end
            x
          end
        end
      end

    private

      def reverse_adjacency
        @reverse_adjacency ||= begin
          reverse = {}
          nodes.each { |node| reverse[node] = [] }
          adjacency.each do |src, targets|
            targets.each { |dst| reverse[dst] << src }
          end
          reverse
        end
      end
    end
  end
end
