require 'kramdown/parser'
require 'kramdown/converter'

module Kramdown

  # The kramdown version.
  VERSION = '0.1.0'

  # The main class.
  class Document

    # The element tree of the document.
    attr_accessor :tree

    # The options hash which holds the options for the Kramdown document.
    attr_accessor :options

    # An array of warning messages.
    attr_reader :warnings

    # Holds needed parse information like ALDs, link definitions, ...
    attr_reader :parse_infos

    # Create a new Kramdown document from the string +source+ and with the +options+.
    def initialize(source, options = {})
      @options = {
        :footnote_nr => 1,
        :filter_html => [],
        :parse_span_html => true,
        :parse_block_html => true,
      }.merge(options)
      @warnings = []
      @parse_infos = {}
      @tree = Parser::Kramdown.parse(source, self)
    end

    # Convert the document to HTML. Uses the Converter::ToHtml class for doing the conversion.
    def to_html
      Converter::Html.convert(@tree, self)
    end

  end


  # The base class for the elements of the parse tree.
  class Element

    # The element type.
    attr_accessor :type

    # The value of the element.
    attr_accessor :value

    # The options hash for the element. It is used for storing arbitray options as well as the
    # attributes of the element under the <tt>:attr</tt> key.
    attr_accessor :options

    # The child elements of this element.
    attr_accessor :children

    def initialize(type, value = nil, options = {}) #:nodoc:
      @type, @value, @options = type, value, options
      @children = []
    end

  end

end

