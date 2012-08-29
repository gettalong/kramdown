# -*- coding: utf-8 -*-
#
#--
# Copyright (C) 2009-2012 Thomas Leitner <t_leitner@gmx.at>
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

module Kramdown

  module Parser

    # == \Base class for parsers
    #
    # This class serves as base class for parsers. It provides common methods that can/should be
    # used by all parsers, especially by those using StringScanner for parsing.
    #
    # A parser object is used as a throw-away object, i.e. it is only used for storing the needed
    # state information during parsing. Therefore one can't instantiate a parser object directly but
    # only use the Base::parse method.
    #
    # == Implementing a parser
    #
    # Implementing a new parser is rather easy: just derive a new class from this class and put it
    # in the Kramdown::Parser module -- the latter is needed so that the auto-detection of the new
    # parser works correctly. Then you need to implement the +#parse+ method which has to contain
    # the parsing code.
    #
    # Have a look at the Base::parse, Base::new and Base#parse methods for additional information!
    class Base

      # The hash with the parsing options.
      attr_reader :options

      # The array with the parser warnings.
      attr_reader :warnings

      # The original source string.
      attr_reader :source

      # The root element of element tree that is created from the source string.
      attr_reader :root

      # Initialize the parser object with the +source+ string and the parsing +options+.
      #
      # The @root element, the @warnings array and @text_type (specifies the default type for newly
      # created text nodes) are automatically initialized.
      def initialize(source, options)
        @source = source
        @options = Kramdown::Options.merge(options)
        @root = Element.new(:root, nil, nil, :encoding => (source.encoding rescue nil))
        @warnings = []
        @text_type = :text
      end
      private_class_method(:new, :allocate)

      # Parse the +source+ string into an element tree, possibly using the parsing +options+, and
      # return the root element of the element tree and an array with warning messages.
      #
      # Initializes a new instance of the calling class and then calls the +#parse+ method that must
      # be implemented by each subclass.
      def self.parse(source, options = {})
        parser = new(source, options)
        parser.parse
        [parser.root, parser.warnings]
      end

      # Parse the source string into an element tree.
      #
      # The parsing code should parse the source provided in @source and build an element tree the
      # root of which should be @root.
      #
      # This is the only method that has to be implemented by sub-classes!
      def parse
        raise NotImplementedError
      end

      # Add the given warning +text+ to the warning array.
      def warning(text)
        @warnings << text
        #TODO: add position information
      end

      # Modify the string +source+ to be usable by the parser (unifies line ending characters to
      # +\n+ and makes sure +source+ ends with a new line character).
      def adapt_source(source)
        source.gsub(/\r\n?/, "\n").chomp + "\n"
      end

      # This helper method adds the given +text+ either to the last element in the +tree+ if it is a
      # +type+ element or creates a new text element with the given +type+.
      def add_text(text, tree = @tree, type = @text_type)
        if tree.children.last && tree.children.last.type == type
          tree.children.last.value << text
        elsif !text.empty?
          tree.children << Element.new(type, text)
        end
      end

      # Extract the part of the StringScanner +strscan+ backed string specified by the +range+. This
      # method works correctly under Ruby 1.8 and Ruby 1.9.
      def extract_string(range, strscan)
        result = nil
        if strscan.string.respond_to?(:encoding)
          begin
            enc = strscan.string.encoding
            strscan.string.force_encoding('ASCII-8BIT')
            result = strscan.string[range].force_encoding(enc)
          ensure
            strscan.string.force_encoding(enc)
          end
        else
          result = strscan.string[range]
        end
        result
      end

    end

  end

end
