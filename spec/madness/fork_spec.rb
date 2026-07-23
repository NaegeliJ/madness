# Specs for the fork-specific features:
#   * vault-wide wikilink resolution (MarkdownDocument#parse_shortlinks)
#   * Obsidian-style callouts (CustomRenderer#block_quote)
#
# These use plain expectations (no approvals) so they run non-interactively.

describe 'Madness fork features' do
  before do
    config.reset
    config.auto_h1 = false
    config.auto_toc = false
    config.highlighter = false
    config.mermaid = false
  end

  describe 'vault-wide wikilinks' do
    let(:vault) { File.expand_path 'spec/fixtures/wikilinks' }

    before do
      config.path = 'spec/fixtures/wikilinks'
      config.shortlinks = true
    end

    def render(markdown, dir:)
      MarkdownDocument.new(markdown, dir: File.join(vault, dir)).text
    end

    it 'resolves a wikilink to a note in a nested folder' do
      expect(render('[[Nested Note]]', dir: '.'))
        .to eq '[Nested Note](sub/Nested%20Note)'
    end

    it 'resolves a wikilink upward from a nested note' do
      expect(render('[[Root Note]]', dir: 'sub'))
        .to eq '[Root Note](../Root%20Note)'
    end

    it 'resolves regardless of case' do
      expect(render('[[nested note]]', dir: '.'))
        .to eq '[nested note](sub/Nested%20Note)'
    end

    it 'supports an alias label with the pipe syntax' do
      expect(render('[[Nested Note|see this]]', dir: '.'))
        .to eq '[see this](sub/Nested%20Note)'
    end

    it 'appends a heading anchor' do
      expect(render('[[Nested Note#Some Heading]]', dir: '.'))
        .to eq '[Nested Note#Some Heading](sub/Nested%20Note#some-heading)'
    end

    it 'falls back to the escaped name for an unknown note' do
      expect(render('[[No Such Note]]', dir: '.'))
        .to eq '[No Such Note](No%20Such%20Note)'
    end
  end

  describe 'callouts' do
    before do
      # Enable the highlighter so the CustomRenderer (which handles callouts)
      # is used by the redcarpet handler.
      config.highlighter = true
    end

    def html(markdown)
      MarkdownDocument.new(markdown, title: 'Callouts').to_html
    end

    it 'renders a basic callout with a default title' do
      result = html "> [!NOTE]\n> Body text."
      expect(result).to include '<div class="callout callout-note" data-callout="note">'
      expect(result).to include '<div class="callout-title">Note</div>'
      expect(result).to include '<p>Body text.</p>'
    end

    it 'uses a custom title when provided' do
      result = html "> [!WARNING] Watch out\n> Body."
      expect(result).to include 'class="callout callout-warning"'
      expect(result).to include '<div class="callout-title">Watch out</div>'
    end

    it 'renders a foldable callout as an open details element' do
      result = html "> [!TIP]+ Open\n> Body."
      expect(result).to include '<details class="callout callout-tip callout-foldable" data-callout="tip" open>'
      expect(result).to include '<summary class="callout-title">Open</summary>'
    end

    it 'renders a collapsed foldable callout as a closed details element' do
      result = html "> [!DANGER]- Closed\n> Body."
      expect(result).to include '<details class="callout callout-danger callout-foldable" data-callout="danger">'
      expect(result).not_to include 'callout-danger callout-foldable" data-callout="danger" open'
    end

    it 'splits adjacent (redcarpet-merged) callouts into separate blocks' do
      result = html "> [!NOTE]\n> First.\n\n> [!WARNING]\n> Second."
      expect(result).to include 'class="callout callout-note"'
      expect(result).to include 'class="callout callout-warning"'
    end

    it 'leaves a regular blockquote untouched' do
      result = html '> Just a quote.'
      expect(result).to include "<blockquote>\n<p>Just a quote.</p>\n</blockquote>"
      expect(result).not_to include 'callout'
    end
  end
end
