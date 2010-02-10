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

module Kramdown

  # This module defines all options that are used by parsers and/or converters.
  module Options

    # Helper class introducing a boolean type for specifying boolean values (+true+ and +false+) as
    # option types.
    class Boolean

      # Return +true+ if +other+ is either +true+ or +false+
      def self.===(other)
        FalseClass === other || TrueClass === other
      end

    end

    # ----------------------------
    # :section: Option definitions
    #
    # This sections informs about the methods that can be used on the Options class.
    # ----------------------------

    # Contains the definition of an option.
    Definition = Struct.new(:name, :type, :default, :desc)

    # Allowed option types
    ALLOWED_TYPES = [String, Integer, Float, Symbol, Boolean, Array, Object]

    @options = {}

    # Define a new option called +name+ (a Symbol) with the given +type+ (String, Integer, Float,
    # Symbol, Boolean, Array, Object), default value +default+ and the description +desc+.
    #
    # The type 'Object' should only be used if none of the other types suffices because such an
    # option will be opaque!
    def self.define(name, type, default, desc)
      raise ArgumentError, "Option name #{name} is already used" if @options.has_key?(name)
      raise ArgumentError, "Invalid option type #{type} specified" if !ALLOWED_TYPES.include?(type)
      raise ArgumentError, "Invalid type for default value" if !(type === default) && !default.nil?
      @options[name] = Definition.new(name, type, default, desc)
    end

    # Return all option definitions.
    def self.definitions
      @options
    end

    # Return +true+ if an option +name+ is defined.
    def self.defined?(name)
      @options.has_key?(name)
    end

    # Return a Hash with the default values for all options.
    def self.defaults
      temp = {}
      @options.each {|n, o| temp[o.name] = o.default}
      temp
    end

    # Merge the #defaults Hash with the parsed options from the given Hash.
    def self.merge(hash)
      temp = defaults
      hash.each do |k,v|
        next unless @options.has_key?(k)
        temp[k] = parse(k, v)
      end
      temp
    end

    # Parse the given value +data+ as if it was a value for the option +name+ and return the parsed
    # value with the correct type.
    #
    # If +data+ already has the correct type, it is just returned. Otherwise it is converted to a
    # String and then to the correct type.
    def self.parse(name, data)
      raise ArgumentError, "No option named #{name} defined" if !@options.has_key?(name)
      return data if @options[name].type === data
      data = data.to_s
      if @options[name].type == String
        data
      elsif @options[name].type == Integer
        Integer(data)
      elsif @options[name].type == Float
        Float(data)
      elsif @options[name].type == Symbol
        (data.empty? ? nil : data.to_sym)
      elsif @options[name].type == Boolean
        data.downcase.strip != 'false' && !data.empty?
      elsif @options[name].type == Array
        data.split(/\s+/)
      end
    end

    # ----------------------------
    # :section: Option Definitions
    #
    # This sections contains all option definitions that are used by the included
    # parsers/converters.
    # ----------------------------

    define(:template, String, '', "The name of an ERB template file that should be used to wrap the output")

    define(:auto_ids, Boolean, true, "Use automatic header ID generation (used in kramdown parser)")
    define(:parse_block_html, Boolean, false, "Process kramdown syntax in block HTML tags (used in kramdown parser)")
    define(:parse_span_html, Boolean, true, "Process kramdown syntax in span HTML tags (used in kramdown parser)")
    define(:extension, Object, nil, "An object for handling the extensions (used in kramdown parser)")

    define(:footnote_nr, Integer, 1, "The initial number used for creating the link to the first footnote (used in HTML converter)")

    define(:filter_html, Array, [], "An array of HTML tags that should be filtered from the output (used in HTML converter)")
    define(:coderay_wrap, Symbol, :div, "How the highlighted code should be wrapped (used in HTML converter)")
    define(:coderay_line_numbers, Symbol, :inline, "How and if line numbers should be shown (used in HTML converter)")
    define(:coderay_line_number_start, Integer, 1, "The start value for the line numbers (used in HTML converter)")
    define(:coderay_tab_width, Integer, 8, "The tab width used in highlighted code (used in HTML converter)")
    define(:coderay_bold_every, Integer, 10, "How often a line number should be made bold (used in HTML converter)")
    define(:coderay_css, Symbol, :style, "Defines how the highlighted code gets styled (used in HTML converter)")

  end

end
