module Madness
  # Handle the navigation links for a given directory
  class Navigation
    include ServerHelper

    using ArrayRefinements
    using StringRefinements

    attr_reader :dir

    def initialize(dir)
      @dir = dir
    end

    def links
      @links ||= if config.sort_order == 'mixed'
        directory.list.nat_sort(by: :href)
      else
        directory.list
      end
    end

    def tree?
      config.nav_tree
    end

    def tree
      @tree ||= sort_tree(root_directory.tree)
    end

    def current_path
      dir
    end

    def caption
      @caption ||= (dir == docroot ? 'Index' : File.basename(dir).to_label)
    end

    def with_search?
      true
    end

  private

    def directory
      @directory ||= Directory.new(dir)
    end

    def root_directory
      @root_directory ||= Directory.new(docroot)
    end

    def sort_tree(items)
      sorted = config.sort_order == 'mixed' ? items.nat_sort(by: :href) : items
      sorted.each do |item|
        item.children = sort_tree(item.children) if item.dir? && item.children
      end
      sorted
    end

    def config
      Settings.instance
    end
  end
end
