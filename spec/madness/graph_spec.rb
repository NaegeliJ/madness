# Specs for the built-in Ruby graph (Madness::Graph and its Metrics).
# The fixture forms a tree, so every internal node is an articulation point
# and every edge is a bridge, which pins down the Tarjan implementation.
#
#   Hub -> Leaf A, Leaf B, branch/Bridge
#   branch/Bridge -> branch/Far

describe Madness::Graph do
  subject(:data) { described_class.new(File.expand_path('spec/fixtures/graph')).data }

  before { config.reset }

  def edge_set(links)
    links.map { |link| [link[:source], link[:target]] }.sort
  end

  it 'builds nodes with ids mirroring viewer paths' do
    expect(data[:nodes].map { |n| n[:id] }.sort).to eq [
      'Hub', 'Leaf A', 'Leaf B', 'branch/Bridge', 'branch/Far'
    ]
  end

  it 'resolves wikilinks vault-wide into directed edges' do
    expect(edge_set(data[:links])).to eq [
      ['Hub', 'Leaf A'],
      ['Hub', 'Leaf B'],
      ['Hub', 'branch/Bridge'],
      ['branch/Bridge', 'branch/Far'],
    ]
  end

  it 'reports connectivity stats' do
    expect(data[:stats]).to include(
      node_count: 5,
      edge_count: 4,
      is_connected: true,
      connected_components: 1,
    )
  end

  it 'identifies articulation points (internal tree nodes)' do
    points = data[:nodes].select { |n| n[:is_articulation_point] }.map { |n| n[:id] }
    expect(points.sort).to eq ['Hub', 'branch/Bridge']
  end

  it 'identifies every tree edge as a bridge' do
    bridges = data[:bridges].map { |b| [b[:source], b[:target]].sort }.sort
    expect(bridges).to eq [
      ['Hub', 'Leaf A'],
      ['Hub', 'Leaf B'],
      ['Hub', 'branch/Bridge'],
      ['branch/Bridge', 'branch/Far'],
    ]
  end

  it 'computes total degree per node' do
    degree = data[:nodes].to_h { |n| [n[:id], n[:degree]] }
    expect(degree).to eq(
      'Hub' => 3, 'Leaf A' => 1, 'Leaf B' => 1, 'branch/Bridge' => 2, 'branch/Far' => 1
    )
  end

  it 'exposes centralities for every node' do
    node = data[:nodes].find { |n| n[:id] == 'Hub' }
    expect(node).to include(:eigenvector, :betweenness, :closeness)
  end
end
