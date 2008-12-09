require 'kramdown/parser'
require 'kramdown/converter'

module Kramdown

  VERSION = '0.1.0'

  class Document

    attr_accessor :tree
    attr_accessor :options

    def initialize(source, options = {})
      @tree = Element.new(:root)
      @options = {
        :link_defs => {}
      }
      Parser.parse(source, self)
    end

    def to_html
      Converter::ToHtml.convert(@tree, self)
    end

  end

  class Element

    attr_accessor :type
    attr_accessor :value
    attr_accessor :options
    attr_accessor :children

    def initialize(type, value = nil, options = {})
      @type, @value, @options = type, value, options
      @children = []
    end

  end

end

