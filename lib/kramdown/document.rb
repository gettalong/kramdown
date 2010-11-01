# -*- coding: utf-8 -*-
#
#--
# Copyright (C) 2009-2010 Thomas Leitner <t_leitner@gmx.at>
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
require 'kramdown/options'
require 'kramdown/utils'

module Kramdown

  # Return the data directory for kramdown.
  def self.data_dir
    unless defined?(@@data_dir)
      require 'rbconfig'
      @@data_dir = File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'data', 'kramdown'))
      @@data_dir = File.expand_path(File.join(Config::CONFIG["datadir"], "kramdown")) if !File.exists?(@@data_dir)
      raise "kramdown data directory not found! This is a bug, please report it!" unless File.directory?(@@data_dir)
    end
    @@data_dir
  end


  # The main interface to kramdown.
  #
  # This class provides a one-stop-shop for using kramdown to convert text into various output
  # formats. Use it like this:
  #
  #   require 'kramdown'
  #   doc = Kramdown::Document.new('This *is* some kramdown text')
  #   puts doc.to_html
  #
  # The #to_html method is a shortcut for using the Converter::Html class.
  #
  # The second argument to the ::new method is an options hash for customizing the behaviour of the
  # used parser and the converter. See Document::new for more information!
  class Document

    # The root element of the element tree. It is immediately available after the #new method has
    # been called.
    attr_accessor :root

    # The options hash which holds the options for parsing/converting the Kramdown document.
    attr_reader :options

    # An array of warning messages. It is filled with warnings during the parsing phase (i.e. in
    # ::new) and the conversion phase.
    attr_reader :warnings


    # Create a new Kramdown document from the string +source+ and use the provided +options+. The
    # options that can be used are defined in the Options module.
    #
    # The special options key <tt>:input</tt> can be used to select the parser that should parse the
    # +source+. It has to be the name of a class in the Kramdown::Parser module. For example, to
    # select the kramdown parser, one would set the <tt>:input</tt> key to +Kramdown+. If this key
    # is not set, it defaults to +Kramdown+.
    #
    # The +source+ is immediately parsed by the selected parser so that the root element is
    # immediately available and the output can be generated.
    def initialize(source, options = {})
      @options = Options.merge(options).freeze
      parser = (options[:input] || 'kramdown').to_s
      parser = parser[0..0].upcase + parser[1..-1]
      if Parser.const_defined?(parser)
        @root, @warnings = Parser.const_get(parser).parse(source, @options)
      else
        raise Kramdown::Error.new("kramdown has no parser to handle the specified input format: #{options[:input]}")
      end
    end

    # Check if a method is invoked that begins with +to_+ and if so, try to instantiate a converter
    # class (i.e. a class in the Kramdown::Converter module) and use it for converting the document.
    #
    # For example, +to_html+ would instantiate the Kramdown::Converter::Html class.
    def method_missing(id, *attr, &block)
      if id.to_s =~ /^to_(\w+)$/ && (name = $1[0..0].upcase + $1[1..-1]) && Converter.const_defined?(name)
        output, warnings = Converter.const_get(name).convert(@root, @options)
        @warnings.concat(warnings)
        output
      else
        super
      end
    end

    def inspect #:nodoc:
      "<KD:Document: options=#{@options.inspect} root=#{@root.inspect} warnings=#{@warnings.inspect}>"
    end

  end


  # Represents all elements in the element tree.
  #
  # kramdown only uses this one class for representing all available elements in an element tree
  # (paragraphs, headers, emphasis, ...). The type of element can be set via the #type accessor.
  #
  # == \Element Descriptions
  #
  # Following is a list of all supported element types.
  #
  #
  # === :blank
  #
  # [Category] Block-level element
  # [Usage context] Where block-level elements are expected
  # [Content model] Empty
  #
  # Represents one or more blank lines. It is not allowed to have two or more consecutive blank
  # elements.
  #
  # The +value+ field may contain the original content of the blank lines.
  #
  #
  # === :p
  #
  # [Category] Block-level element
  # [Usage context] Where block-level elements are expected
  # [Content model] Span-level elements
  #
  # Represents a paragraph.
  #
  # If the option <tt>:transparent</tt> is +true+, this element just represents a block of text.
  # I.e. this element just functions as a container for span-level elements.
  #
  #
  # === :header
  #
  # [Category] Block-level element
  # [Usage context] Where block-level elements are expected
  # [Content model] Span-level elements
  #
  # Represents a header.
  #
  # The option <tt>:level</tt> specifies the header level and has to contain a number between 1 and
  # \6. The option <tt>:raw_text</tt> has to contain the raw header text.
  #
  #
  # === :blockquote
  #
  # [Category] Block-level element
  # [Usage context] Where block-level elements are expected
  # [Content model] Block-level elements
  #
  # Represents a blockquote.
  #
  #
  # === :codeblock
  #
  # [Category] Block-level element
  # [Usage context] Where block-level elements are expected
  # [Content model] Empty
  #
  # Represents a code block, i.e. a block of text that should be used as-is.
  #
  # The +value+ field has to contain the content of the code block.
  #
  #
  # === :ul
  #
  # [Category] Block-level element
  # [Usage context] Where block-level elements are expected
  # [Content model] One or more :li elements
  #
  # Represents an unordered list.
  #
  #
  # === :ol
  #
  # [Category] Block-level element
  # [Usage context] Where block-level elements are expected
  # [Content model] One or more :li elements
  #
  # Represents an ordered list.
  #
  #
  # === :li
  #
  # [Category] None
  # [Usage context] Inside :ol and :ul elements
  # [Content model] Block-level elements
  #
  # Represents a list item of an ordered or unordered list.
  #
  #
  # === :dl
  #
  # [Category] Block-level element
  # [Usage context] Where block-level elements are expected
  # [Content model] One or more groups each consisting of one or more :dt elements followed by one
  #                 or more :dd elements.
  #
  # Represents a definition list which contains groups consisting of terms and definitions for them.
  #
  #
  # === :dt
  #
  # [Category] None
  # [Usage context] Before :dt or :dd elements inside a :dl elment
  # [Content model] Span-level elements
  #
  # Represents the term part of a term-definition group in a definition list.
  #
  #
  # === :dd
  #
  # [Category] None
  # [Usage context] After :dt or :dd elements inside a :dl elment
  # [Content model] Block-level elements
  #
  # Represents the definition part of a term-definition group in a definition list.
  #
  #
  # === :table
  #
  # [Category] Block-level element
  # [Usage context] Where block-level elements are expected
  # [Content model] Zero or one :thead elements, one or more :tbody elements, zero or one :tfoot
  #                 elements
  #
  # Represents a table. Each table row (i.e. :tr element) of the table has to contain the same
  # number of :td elements.
  #
  # The option <tt>:alignment</tt> has to be an array containing the alignment values, exactly one
  # for each column of the table. The possible alignment values are <tt>:left</tt>,
  # <tt>:center</tt>, <tt>:right</tt> and <tt>:default</tt>.
  #
  #
  # === :thead
  #
  # [Category] None
  # [Usage context] As first element inside a :table element
  # [Content model] One or more :tr elements
  #
  # Represents the table header.
  #
  #
  # === :tbody
  #
  # [Category] None
  # [Usage context] After a :thead element but before a :tfoot element inside a :table element
  # [Content model] One or more :tr elements
  #
  # Represents a table body.
  #
  #
  # === :tfoot
  #
  # [Category] None
  # [Usage context] As last element inside a :table element
  # [Content model] One or more :tr elements
  #
  # Represents the table footer.
  #
  #
  # === :tr
  #
  # [Category] None
  # [Usage context] Inside :thead, :tbody and :tfoot elements
  # [Content model] One or more :td elements
  #
  # Represents a table row.
  #
  #
  # === :td
  #
  # [Category] None
  # [Usage context] Inside :tr elements
  # [Content model] As child of :thead/:tr span-level elements, as child of :tbody/:tr and
  #                 :tfoot/:tr block-level elements
  #
  # Represents a table cell.
  #
  #
  #
  #
  #
  # === :a
  # === :text
  # === :hr
  # === :html_element
  # === :xml_comment
  # === :xml_pi
  # === :html_doctype
  # === :comment
  # === :br
  # === :a
  # === :img
  # === :codespan
  # === :footnote
  # === :raw
  # === :em
  # === :convert_strong
  # === :entity
  # === :typographic_sym
  # === :smart_quote
  # === :math
  # === :abbreviation
  # === :root
  class Element

    # A symbol representing the element type. For example, <tt>:p</tt> or <tt>:blockquote</tt>.
    attr_accessor :type

    # The value of the element. The interpretation of this field depends on the type of the element.
    # Many elements don't use this field.
    attr_accessor :value

    # The child elements of this element.
    attr_accessor :children


    # Create a new Element object of type +type+. The optional parameters +value+, +attr+ and
    # +options+ can also be set in this constructor for convenience.
    def initialize(type, value = nil, attr = nil, options = nil)
      @type, @value, @attr, @options = type, value, (Utils::OrderedHash.new.merge!(attr) if attr), options
      @children = []
    end

    # The attributes of the element. Uses an Utils::OrderedHash to retain the insertion order.
    def attr
      @attr ||= Utils::OrderedHash.new
    end

    # The options hash for the element. It is used for storing arbitray options.
    def options
      @options ||= {}
    end

    def inspect #:nodoc:
      "<kd:#{@type}#{@value.nil? ? '' : ' ' + @value.inspect} #{@attr.inspect}#{options.empty? ? '' : ' ' + @options.inspect}#{@children.empty? ? '' : ' ' + @children.inspect}>"
    end

    CATEGORY = {} # :nodoc:
    [:blank, :p, :header, :blockquote, :codeblock, :ul, :ol, :dl, :table, :hr].each {|b| CATEGORY[b] = :block}
    [:text, :a, :br, :img, :codespan, :footnote, :em, :strong, :entity, :typographic_sym,
     :smart_quote, :abbreviation].each {|b| CATEGORY[b] = :span}

    # Return the category of +el+ which can be <tt>:block</tt>, <tt>:span</tt> or +nil+.
    #
    # Most elements have a fixed category, however, some elements can either appear in a block-level
    # or a span-level context. These elements need to have the option <tt>:category</tt> correctly
    # set.
    def self.category(el)
      CATEGORY[el.type] || el.options[:category]
    end

  end

end

