require 'cgi'
require 'redcarpet'
require 'rouge'
require 'rouge/plugins/redcarpet'

module Madness
  # Renderer with syntax highlighting support
  class CustomRenderer < Redcarpet::Render::HTML
    include Rouge::Plugins::Redcarpet

    # Matches the leading Obsidian callout marker of a blockquote, e.g.
    # "[!NOTE]", "[!warning]-" or "[!tip]+ Custom title". Captures the type,
    # the optional fold sign (+/-) and the optional title on the same line.
    CALLOUT_MARKER = /\[!(?<type>\w+)\](?<fold>[+-]?)[^\S\n]*(?<title>[^\n<]*)/

    def block_code(code, language)
      if language == 'mermaid'
        # Escape HTML so diagrams using < > characters (class diagrams with
        # <|-- realization arrows, <<interface>> annotations, etc.) survive
        # the browser's HTML parser. Mermaid reads .textContent, which gives
        # back the decoded source.
        "<div class='mermaid'>#{CGI.escapeHTML(code)}</div>"
      else
        super
      end
    end

    # Render Obsidian-style callouts (`> [!NOTE] Title`) as styled callout
    # blocks instead of plain blockquotes. A fold sign (`+`/`-`) turns the
    # callout into a native, JS-free <details> element.
    #
    # Redcarpet merges blockquotes that are only separated by a blank line
    # into a single block_quote call, so one call may carry several callouts
    # (each starting with a "<p>[!TYPE]" paragraph). We split on those
    # boundaries and render each segment independently. A blockquote that
    # contains no callout marker renders as a regular blockquote.
    def block_quote(quote)
      segments = quote.split(/(?=<p>\s*\[!\w+\])/)
      return default_blockquote(quote) unless segments.any? { |segment| callout_segment? segment }

      segments.map { |segment| render_quote_segment segment }.join("\n")
    end

  private

    # Redcarpet's HTML renderer implements block_quote in C, so there is no
    # Ruby superclass method to call. Reproduce its exact output for the
    # non-callout case instead of using `super`.
    def default_blockquote(content)
      "<blockquote>\n#{content}</blockquote>\n"
    end

    def callout_segment?(segment)
      segment =~ /\A\s*<p>\s*\[!\w+\]/
    end

    def render_quote_segment(segment)
      unless callout_segment? segment
        return '' if segment.strip.empty?

        return default_blockquote(segment)
      end

      type = fold = title = nil
      body = segment.sub(CALLOUT_MARKER) do
        match = Regexp.last_match
        type  = match[:type].downcase
        fold  = match[:fold]
        given = match[:title].strip
        title = given.empty? ? type.capitalize : given
        ''
      end

      callout type, title, fold, cleanup_callout_body(body)
    end

    # Remove the now-empty paragraph left behind by the marker and trim
    # surrounding whitespace so the callout body renders cleanly.
    def cleanup_callout_body(body)
      body.gsub(%r{<p>\s*</p>}, '').sub(%r{(<p>)\s+}, '\1').strip
    end

    def callout(type, title, fold, body)
      classes = "callout callout-#{type}"

      if ['+', '-'].include? fold
        open = fold == '+' ? ' open' : ''
        <<~HTML
          <details class="#{classes} callout-foldable" data-callout="#{type}"#{open}>
          <summary class="callout-title">#{title}</summary>
          <div class="callout-content">
          #{body}
          </div>
          </details>
        HTML
      else
        <<~HTML
          <div class="#{classes}" data-callout="#{type}">
          <div class="callout-title">#{title}</div>
          <div class="callout-content">
          #{body}
          </div>
          </div>
        HTML
      end
    end
  end
end
