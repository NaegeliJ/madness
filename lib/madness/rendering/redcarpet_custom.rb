require 'cgi'
require 'redcarpet'
require 'rouge'
require 'rouge/plugins/redcarpet'

module Madness
  # Renderer with syntax highlighting support
  class CustomRenderer < Redcarpet::Render::HTML
    include Rouge::Plugins::Redcarpet

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
  end
end
