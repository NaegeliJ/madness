require 'nokogiri'

describe 'clipboard code selection' do
  let(:markdown) do
    <<~MARKDOWN
      Inline `code_word` and block code:

      ```ruby
      def say(message = "Hi")
        puts message
      end
      ```
    MARKDOWN
  end

  let(:selector) do
    File.read('app/public/js/clipboard.js')[/new ClipboardJS\('([^']+)'/, 1]
  end

  let(:fragment) do
    Nokogiri::HTML.fragment(MarkdownDocument.new(markdown, title: 'Clipboard').to_html)
  end

  after do
    config.reset
  end

  it 'targets redcarpet code blocks without targeting inline code' do
    expect(selector).to eq 'pre > code'
    expect(fragment.css(selector).map(&:text).join).to include 'def say'
    expect(fragment.css(selector).map(&:text).join).not_to include 'code_word'
  end

  context 'with pandoc renderer' do
    before { config.renderer = 'pandoc' }

    it 'targets pandoc code blocks without targeting inline code' do
      expect(selector).to eq 'pre > code'
      expect(fragment.css(selector).map(&:text).join).to include 'def say'
      expect(fragment.css(selector).map(&:text).join).not_to include 'code_word'
    end
  end
end
