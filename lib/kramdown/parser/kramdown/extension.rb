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
          opts.select do |k,v|
            k = k.to_sym
            if Kramdown::Options.defined?(k)
              parser.doc.options[k] = Kramdown::Options.parse(k, v) rescue parser.doc.options[k]
              false
            else
              true
            end
          end.each do |k,v|
            parser.warning("Unknown kramdown option '#{k}'")
          end
        end

      end


      EXT_BLOCK_START_STR = "^#{OPT_SPACE}\\{::(%s):(:)?(#{ALD_ANY_CHARS}*)\\}\s*?\n"
      EXT_BLOCK_START = /#{EXT_BLOCK_START_STR % ALD_ID_NAME}/

      # Parse the block extension at the current location.
      def parse_extension_block
        @src.pos += @src.matched_size

        ext = @src[1]
        opts = {}
        body = nil
        parse_attribute_list(@src[3], opts)

        warn('DEPRECATION warning: This syntax is deprecated, use the new extension syntax')
        if !%w{comment nomarkdown options}.include?(ext)
          warn('DEPRECATION warning: Custom extensions will be removed in a future version - use a template processor like ERB instead')
        end

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


      ##########################################
      ### Code for handling new extension syntax
      ##########################################

      def handle_extension(name, opts, body, type)
        case name
        when 'comment'
          # nothing to do
        when 'nomarkdown'
          @tree.children << Element.new(:raw, body, :type => type) if body.kind_of?(String)
        when 'options'
          opts.select do |k,v|
            k = k.to_sym
            if Kramdown::Options.defined?(k)
              @doc.options[k] = Kramdown::Options.parse(k, v) rescue @doc.options[k]
              false
            else
              true
            end
          end.each do |k,v|
            warning("Unknown kramdown option '#{k}'")
          end
        else
          warning("Invalid extension name '#{name}' specified - ignoring extension")
        end
      end


      EXT_STOP_STR = "\\{:/(%s)?\\}"
      EXT_STOP = /#{EXT_STOP_STR % ALD_ID_NAME}/
      EXT_SPAN_START = /\{:(\w+)(?:\s(#{ALD_ANY_CHARS}*?)|)(\/)?\}|#{EXT_STOP}/

      # Parse the extension span at the current location.
      def parse_span_extension
        @src.pos += @src.matched_size

        if @src[4] || @src.matched == '{:/}'
          name = (@src[4] ? "for '#{@src[4]}' " : '')
          warning("Invalid extension stop tag #{name}found - ignoring it")
          return
        end

        ext = @src[1]
        opts = {}
        body = nil
        parse_attribute_list(@src[2] || '', opts)

        if !@src[3]
          stop_re = /#{EXT_STOP_STR % ext}/
          if result = @src.scan_until(stop_re)
            body = result.sub!(stop_re, '')
          else
            warning("No stop tag for extension '#{ext}' found - treating it as extension without body")
          end
        end

        handle_extension(ext, opts, body, :span)
      end
      define_parser(:span_extension, EXT_SPAN_START, '\{:/?')

    end
  end
end
