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

require 'kramdown/parser/kramdown/attribute_list'

module Kramdown
  module Parser
    class Kramdown

      # The base extension class.
      #
      # This class provides implementations for the default extensions defined in the kramdown
      # specification.
      #
      # An extension is a method called <tt>parse_EXTNAME</tt> where +EXTNAME+ is the extension name.
      # These methods are called with three parameters:
      #
      # [+parser+]
      #    The parser instance from which the extension method is called.
      # [+opts+]
      #    A hash containing the options set in the extension.
      # [+body+]
      #    A string containing the body of the extension. If no body is available, this is +nil+.
      class Extension

        # Just ignore everything and do nothing.
        def parse_comment(parser, opts, body)
          nil
        end

        # Add the body (if available) as <tt>:raw</tt> Element to the +parser.tree+.
        def parse_nomarkdown(parser, opts, body)
          parser.tree.children << Element.new(:raw, body) if body.kind_of?(String)
        end

        # Update the document and parser options with the options set in +opts+.
        def parse_options(parser, opts, body)
          if val = opts.delete('auto_ids')
            parser.doc.options[:auto_ids] = parser.options[:auto_ids] = boolean_value(val)
          end
          if val = opts.delete('filter_html')
            parser.doc.options[:filter_html] = val.split(/\s+/)
          end
          if val = opts.delete('footnote_nr')
            parser.doc.options[:footnote_nr] = Integer(val) rescue parser.doc.options[:footnote_nr]
          end
          if val = opts.delete('parse_block_html')
            parser.doc.options[:parse_block_html] = parser.options[:parse_block_html] = boolean_value(val)
          end
          if val = opts.delete('parse_span_html')
            parser.doc.options[:parse_span_html] = parser.options[:parse_span_html] = boolean_value(val)
          end
          if val = opts.delete('coderay_wrap')
            (parser.doc.options[:coderay] ||= {})[:wrap] = (val.empty? ? nil : val.to_sym)
          end
          if val = opts.delete('coderay_css')
            (parser.doc.options[:coderay] ||= {})[:css] = val.to_sym
          end
          if val = opts.delete('coderay_tab_width')
            (parser.doc.options[:coderay] ||= {})[:tab_width] = val.to_i
          end
          if val = opts.delete('coderay_line_numbers')
            (parser.doc.options[:coderay] ||= {})[:line_numbers] = (val.empty? ? nil : val.to_sym)
          end
          if val = opts.delete('coderay_line_number_start')
            (parser.doc.options[:coderay] ||= {})[:line_number_start] = val.to_i
          end
          if val = opts.delete('coderay_bold_every')
            (parser.doc.options[:coderay] ||= {})[:bold_every] = val.to_i
          end

          opts.each {|k,v| parser.warning("Unknown kramdown options '#{k}'")}
        end

        def boolean_value(val)
          val.downcase.strip != 'false' && !val.empty?
        end

      end


      EXT_BLOCK_START_STR = "^#{OPT_SPACE}\\{::(%s):(:)?(#{ALD_ANY_CHARS}*)\\}\s*?\n"
      EXT_BLOCK_START = /#{EXT_BLOCK_START_STR % ALD_ID_NAME}/

      # Parse the extension block at the current location.
      def parse_extension_block
        @src.pos += @src.matched_size

        ext = @src[1]
        opts = {}
        body = nil
        parse_attribute_list(@src[3], opts)

        if !@extension.public_methods.map {|m| m.to_s}.include?("parse_#{ext}")
          warning("No extension named '#{ext}' found - ignoring extension block")
          body = :invalid
        end

        if !@src[2]
          stop_re = /#{EXT_BLOCK_START_STR % ext}/
          if result = @src.scan_until(stop_re)
            parse_attribute_list(@src[3], opts)
            body = result.sub!(stop_re, '') if body != :invalid
          else
            body = :invalid
            warning("No ending line for extension block '#{ext}' found - ignoring extension block")
          end
        end

        @extension.send("parse_#{ext}", self, opts, body) if body != :invalid

        true
      end
      define_parser(:extension_block, EXT_BLOCK_START)

    end
  end
end
