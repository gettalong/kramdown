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

  module Utils

    # Provides convenience methods for HTML related tasks.
    #
    # *Note* that this module has to be mixed into a class that has a @root (containing an element
    # of type :root) and an @options (containing an options hash) instance variable so that some of
    # the methods can work correctly.
    module Html

      # Convert the entity +e+ to a string. The optional parameter +original+ may contain the
      # original representation of the entity.
      #
      # This method uses the option +entity_output+ to determine the output form for the entity.
      def entity_to_str(e, original = nil)
        if RUBY_VERSION >= '1.9' && @options[:entity_output] == :as_char &&
            (c = e.char.encode(@root.options[:encoding]) rescue nil) && !ESCAPE_MAP.has_key?(c)
          c
        elsif (@options[:entity_output] == :as_input || @options[:entity_output] == :as_char) && original
          original
        elsif @options[:entity_output] == :numeric || e.name.nil?
          "&##{e.code_point};"
        else
          "&#{e.name};"
        end
      end

      # Return the HTML representation of the attributes +attr+.
      def html_attributes(attr)
        attr.map {|k,v| v.nil? || (k == 'id' && v.strip.empty?) ? '' : " #{k}=\"#{escape_html(v.to_s, :attribute)}\"" }.join('')
      end

      # :stopdoc:
      ESCAPE_MAP = {
        '<' => '&lt;',
        '>' => '&gt;',
        '&' => '&amp;',
        '"' => '&quot;'
      }
      ESCAPE_ALL_RE = /<|>|&/
      ESCAPE_TEXT_RE = Regexp.union(REXML::Parsers::BaseParser::REFERENCE_RE, /<|>|&/)
      ESCAPE_ATTRIBUTE_RE = Regexp.union(REXML::Parsers::BaseParser::REFERENCE_RE, /<|>|&|"/)
      ESCAPE_RE_FROM_TYPE = {
        :all => ESCAPE_ALL_RE,
        :text => ESCAPE_TEXT_RE,
        :attribute => ESCAPE_ATTRIBUTE_RE
      }
      # :startdoc:

      # Escape the special HTML characters in the string +str+. The parameter +type+ specifies what
      # is escaped: :all - all special HTML characters as well as entities, :text - all special HTML
      # characters except the quotation mark but no entities and :attribute - all special HTML
      # characters including the quotation mark but no entities.
      def escape_html(str, type = :all)
        str.gsub(ESCAPE_RE_FROM_TYPE[type]) {|m| ESCAPE_MAP[m] || m}
      end

    end

  end

end
