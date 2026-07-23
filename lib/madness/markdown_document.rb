require 'redcarpet'
require 'pathname'

module Madness
  # Handle a pure markdown document.
  class MarkdownDocument
    include ServerHelper

    using StringRefinements

    attr_reader :markdown, :title

    # +dir+ is the absolute directory of the document being rendered. It is
    # used to resolve wikilinks into paths relative to the current page.
    # When omitted (e.g. in isolated specs) it defaults to the docroot.
    def initialize(markdown, title: nil, dir: nil)
      @markdown = markdown
      @title = title || ''
      @dir = dir
    end

    def text
      @text ||= begin
        result = markdown
        result = parse_toc(result) if config.auto_toc
        result = parse_shortlinks(result) if config.shortlinks
        result = prepend_h1(result) if config.auto_h1
        result
      end
    end

    def to_html
      @to_html ||= renderer.render text
    end

  private

    def renderer
      @renderer ||= Rendering::Handler.new config.renderer
    end

    def parse_toc(input)
      input.gsub '<!-- TOC -->', toc
    end

    def parse_shortlinks(input)
      input.gsub(/\[\[([^\]]+)\]\]/) { shortlink_for $1 }
    end

    # Convert a single wikilink body into a markdown link. Supports the
    # Obsidian forms [[Note]], [[Note|Label]] and [[Note#Anchor]]. The note
    # name is resolved vault-wide (see #shortlink_target), so a wikilink
    # points at the right file regardless of which directory it lives in.
    def shortlink_for(body)
      target, label = body.split('|', 2)
      name, anchor = target.to_s.split('#', 2)
      name = name.to_s.strip
      label = (label || target).to_s.strip

      href = name.empty? ? '' : resolve_shortlink(name)
      href = "#{href}##{anchor.strip.to_slug(config.renderer)}" if anchor && !anchor.strip.empty?

      "[#{label}](#{href})"
    end

    # Resolve a note name to a page href. Falls back to the plain escaped
    # name (the previous behaviour) when no matching file exists, so broken
    # wikilinks degrade gracefully instead of vanishing.
    def resolve_shortlink(name)
      file = shortlink_target name
      return name.to_href unless file

      relative_href file
    end

    # Prefer a file in the current directory (keeps same-directory links
    # working and resolves same-name ambiguity predictably), otherwise fall
    # back to a vault-wide lookup by base name.
    def shortlink_target(name)
      local = File.join(current_dir, "#{name}.md")
      return local if File.file?(local)

      shortlink_index[name.downcase]
    end

    # Map of base name (without extension, downcased) => absolute path for
    # every markdown file under the docroot. Built once per rendered
    # document; the first match for a given name wins.
    def shortlink_index
      @shortlink_index ||=
        Dir.glob(File.join(docroot, '**', '*.md')).each_with_object({}) do |path, index|
          key = File.basename(path, '.md').downcase
          index[key] ||= path
        end
    end

    # Filesystem-relative path from the current document's directory to the
    # target file, without the .md extension and URI-escaped per segment.
    # Since madness serves readme pages with a trailing slash, this path
    # also resolves correctly as a relative link in the browser.
    def relative_href(file)
      relative = Pathname.new(file).relative_path_from(Pathname.new(current_dir)).to_s
      relative = relative.tr('\\', '/').sub(/\.md$/, '')
      relative.split('/').map { |seg| seg == '..' ? seg : seg.to_href }.join('/')
    end

    def current_dir
      @dir || docroot
    end

    def prepend_h1(input)
      return input if has_h1?(input)

      "# #{title}\n\n#{input}"
    end

    def has_h1?(input)
      lines = input.lines(chomp: true).reject(&:empty?)
      return false if lines.empty?

      lines[0].match(/^# \w+/) || (lines[1] && lines[0].match(/^\w+/) && lines[1].start_with?('='))
    end

    def toc
      @toc ||= toc_handler.markdown
    end

    def toc_handler
      @toc_handler ||= InlineTableOfContents.new markdown
    end
  end
end
