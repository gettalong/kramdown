# -*- coding: utf-8 -*-
#
#--
# Copyright (C) 2009 Thomas Leitner <t_leitner@gmx.at>
#
# This file is part of kramdown.
#
# kramdown is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#++
#

require 'kramdown/compatibility'

require 'kramdown/version'
require 'kramdown/error'
require 'kramdown/parser'
require 'kramdown/converter'
require 'kramdown/extension'

module Kramdown

  # The main interface to kramdown.
  #
  # This class provides a one-stop-shop for using kramdown to convert text into various output
  # formats. Use it like this:
  #
  #   require 'kramdown'
  #   doc = Kramdown::Document.new('This *is* some kramdown text')
  #   puts doc.to_html
  #
  # The #to_html method is a shortcut for using the Converter::ToHtml class. If other converters are
  # added later, there may be additional shortcut methods.
  #
  # The second argument to the #new method is an options hash for customizing the behaviour of
  # kramdown.
  class Document

    # Currently available options are:
    #
    # [:auto_ids (used by the parser)]
    #    A boolean value deciding whether automatic header ID generation is used. Default: +false+.
    #
    # [:coderay (used by the HTML converter)]
    #    A hash containing options for the CodeRay syntax highlighter. If this is set to +nil+,
    #    syntax highlighting is disabled. When using the +options+ extension, any CodeRay option can
    #    be set by prefixing it with +coderay_+.
    #
    #    Default:
    #      {:wrap => :div, :line_numbers => :inline, :line_number_start => 1,
    #       :tab_width => 8, :bold_every => 10, :css => :style}
    #
    # [:filter_html (used by the HTML converter)]
    #    An array of HTML tag names that defines which tags should be filtered from the output. For
    #    example, if the value contains +iframe+, then all HTML +iframe+ tags are filtered out and
    #    only the body is displayed. Default: empty array. When using the +options+ extension, the
    #    string value needs to hold the HTML tag names separated by one or more spaces.
    #
    # [:footnote_nr (used by the HTML converter)]
    #    The initial number used for creating the link to the first footnote. Default: +1+. When
    #    using the +options+ extension, the string value needs to be a valid number.
    #
    # [:parse_block_html (used by the parser)]
    #    A boolean value deciding whether kramdown syntax is processed in block HTML tags. Default:
    #    +false+.
    #
    # [:parse_span_html (used by the parser)]
    #    A boolean value deciding whether kramdown syntax is processed in span HTML tags. Default:
    #    +true+.
    #
    # When using the +options+ extension, all boolean values can be set to false by using the
    # string 'false' or an empty string, any other non-empty string will be converted to the value
    # +true+.
    DEFAULT_OPTIONS={
      :footnote_nr => 1,
      :filter_html => [],
      :auto_ids => true,
      :parse_block_html => false,
      :parse_span_html => true,
      :coderay => {:wrap => :div, :line_numbers => :inline,
        :line_number_start => 1, :tab_width => 8, :bold_every => 10, :css => :style}
    }


    # The element tree of the document. It is immediately available after the #new method has been
    # called.
    attr_accessor :tree

    # The options hash which holds the options for parsing/converting the Kramdown document. It is
    # possible that these values get changed during the parsing phase.
    attr_accessor :options

    # An array of warning messages. It is filled with warnings during the parsing phase (i.e. in
    # #new) and the converting phase.
    attr_reader :warnings

    # Holds needed parse information like ALDs, link definitions and so on.
    attr_reader :parse_infos

    # Holds an instance of the extension class.
    attr_reader :extension


    # Create a new Kramdown document from the string +source+ and use the provided +options+ (see
    # DEFAULT_OPTIONS for a list of available options). The +source+ is immediately parsed by the
    # kramdown parser sothat after this call the output can be generated.
    #
    # The parameter +ext+ can be used to set a custom extension class. Note that the default
    # kramdown extensions should be available in the custom extension class.
    def initialize(source, options = {}, ext = nil)
      @options = DEFAULT_OPTIONS.merge(options)
      @warnings = []
      @parse_infos = {}
      @extension = extension || Kramdown::Extension.new
      @tree = Parser::Kramdown.parse(source, self)
    end

    # Convert the document to HTML. Uses the Converter::ToHtml class for doing the conversion.
    def to_html
      Converter::Html.convert(self)
    end

    def inspect #:nodoc:
      "<KD:Document: options=#{@options.inspect} tree=#{@tree.inspect} warnings=#{@warnings.inspect}>"
    end

  end


  # Represents all elements in the parse tree.
  #
  # kramdown only uses this one class for representing all available elements in a parse tree
  # (paragraphs, headers, emphasis, ...). The type of element can be set via the #type accessor.
  class Element

    # A symbol representing the element type. For example, +:p+ or +:blockquote+.
    attr_accessor :type

    # The value of the element. The interpretation of this field depends on the type of the element.
    # Many elements don't use this field.
    attr_accessor :value

    # The options hash for the element. It is used for storing arbitray options as well as the
    # *attributes* of the element under the <tt>:attr</tt> key.
    attr_accessor :options

    # The child elements of this element.
    attr_accessor :children


    # Create a new Element object of type +type+. The optional parameters +value+ and +options+ can
    # also be set in this constructor for convenience.
    def initialize(type, value = nil, options = {})
      @type, @value, @options = type, value, options
      @children = []
    end

    def inspect #:nodoc:
      "<kd:#{@type}#{@value.nil? ? '' : ' ' + @value.inspect}#{options.empty? ? '' : ' ' + @options.inspect}#{@children.empty? ? '' : ' ' + @children.inspect}>"
    end

  end

end

