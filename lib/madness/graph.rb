require 'json'

module Madness
  # Builds a link graph of the vault from [[wikilinks]] and computes the
  # metrics consumed by the /graph page. Everything is computed in pure Ruby
  # on demand, so there is no separate generation step or service.
  #
  # Node ids mirror the viewer URLs (path relative to docroot, no ".md"), so
  # clicking a node in the graph navigates straight to that page.
  class Graph
    include ServerHelper

    using StringRefinements

    WIKILINK = /\[\[([^\]]+)\]\]/

    def initialize(dir = nil)
      @root = dir || docroot
    end

    # The full payload rendered into graph-data.json.
    def data
      @data ||= build
    end

    def to_json(*_args)
      JSON.pretty_generate data
    end

  private

    def build
      files = markdown_files
      ids = id_map files                 # absolute path => node id
      index = basename_index files, ids  # "note name" (downcased) => node id

      nodes = files.map { |file| node_attributes file, ids }
      adjacency = build_adjacency files, ids, index

      metrics = Metrics.new(nodes.map { |n| n[:id] }, adjacency)

      enriched = nodes.map do |node|
        node.merge(
          degree:               metrics.degree[node[:id]],
          eigenvector:          round(metrics.eigenvector[node[:id]]),
          betweenness:          round(metrics.betweenness[node[:id]]),
          closeness:            round(metrics.closeness[node[:id]]),
          is_articulation_point: metrics.articulation_points.include?(node[:id])
        )
      end

      {
        generated_at: Time.now.utc.iso8601,
        stats: {
          node_count:               nodes.size,
          edge_count:               metrics.edge_count,
          is_connected:             metrics.connected?,
          connected_components:     metrics.component_count,
          articulation_point_count: metrics.articulation_points.size,
          bridge_count:             metrics.bridges.size,
        },
        nodes: enriched,
        links: metrics.edges.map { |s, t| { source: s, target: t } },
        bridges: metrics.bridges.map { |s, t| { source: s, target: t } },
      }
    end

    def markdown_files
      Dir.glob(File.join(@root, '**', '*.md')).reject do |path|
        relative(path).split('/').any? { |part| part.start_with?('.') }
      end.sort
    end

    def id_map(files)
      files.each_with_object({}) { |file, map| map[file] = node_id(file) }
    end

    def basename_index(files, ids)
      files.each_with_object({}) do |file, index|
        key = File.basename(file, '.md').downcase
        index[key] ||= ids[file]
      end
    end

    def node_attributes(file, ids)
      text = File.read file
      { id: ids[file], title: title_of(text, file), path: relative(file) }
    end

    def build_adjacency(files, ids, index)
      adjacency = ids.values.each_with_object({}) { |id, adj| adj[id] = [] }

      files.each do |file|
        source = ids[file]
        File.read(file).scan(WIKILINK).each do |match|
          name = wikilink_target match.first
          next if name.empty?

          target = index[name.downcase]
          adjacency[source] << target if target && target != source
        end
        adjacency[source].uniq!
      end

      adjacency
    end

    def wikilink_target(raw)
      raw.split('|', 2).first.split('#', 2).first.strip
    end

    def node_id(file)
      relative(file).sub(/\.md$/, '')
    end

    def relative(file)
      file.sub(/^#{Regexp.escape(@root)}\/?/, '').tr('\\', '/')
    end

    # Best available human title: YAML frontmatter `title:`, then the first
    # real H1 (ATX or Setext, ignoring headings inside code fences), then the
    # file name. Keeps graph labels readable on real vaults.
    def title_of(text, file)
      frontmatter_title(text) || heading_title(text) || File.basename(file, '.md')
    end

    def frontmatter_title(text)
      match = text.match(/\A---\s*\r?\n(.*?)\r?\n---\s*(?:\r?\n|\z)/m)
      return nil unless match

      title = match[1].match(/^title:\s*(.+?)\s*$/)
      return nil unless title

      title[1].strip.gsub(/\A["']|["']\z/, '')
    end

    def heading_title(text)
      lines = text.lines.map(&:chomp)
      fence = nil

      lines.each_with_index do |line, i|
        if fence
          fence = nil if line.start_with?(fence)
          next
        end
        if (open = line[/^(```+|~~~+)/, 1])
          fence = open
          next
        end

        atx = line.match(/^\#\s+(.+?)\s*#*\s*$/)
        return atx[1].strip if atx

        nxt = lines[i + 1]
        return line.strip if !line.strip.empty? && !line.start_with?('#') && nxt&.match?(/^=+\s*$/)
      end

      nil
    end

    def round(value)
      value.round(6)
    end
  end
end
