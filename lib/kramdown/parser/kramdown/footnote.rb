# -*- coding: utf-8 -*-
#
#--
# Copyright (C) 2009-2013 Thomas Leitner <t_leitner@gmx.at>
#
# This file is part of kramdown which is licensed under the MIT.
#++
#

require 'kramdown/parser/kramdown/extensions'
require 'kramdown/parser/kramdown/blank_line'
require 'kramdown/parser/kramdown/codeblock'

module Kramdown
  module Parser
    class Kramdown

      FOOTNOTE_DEFINITION_START = /^#{OPT_SPACE}\[\^(#{ALD_ID_NAME})\]:\s*?(.*?\n#{CODEBLOCK_MATCH})/

      # Parse the foot note definition at the current location.
      def parse_footnote_definition
        @src.pos += @src.matched_size

        el = Element.new(:footnote_def)
        parse_blocks(el, @src[2].gsub(INDENT, ''))
        warning("Duplicate footnote name '#{@src[1]}' - overwriting") if @footnotes[@src[1]]
        (@footnotes[@src[1]] = {})[:content] = el
        @tree.children << Element.new(:eob, :footnote_def)
        true
      end
      define_parser(:footnote_definition, FOOTNOTE_DEFINITION_START)


      FOOTNOTE_MARKER_START = /\[\^(#{ALD_ID_NAME})\]/

      # Parse the footnote marker at the current location.
      def parse_footnote_marker
        @src.pos += @src.matched_size
        fn_def = @footnotes[@src[1]]
        if fn_def
          valid = fn_def[:marker] && fn_def[:stack][0..-2].zip(fn_def[:stack][1..-1]).all? do |par, child|
            par.children.include?(child)
          end
          if !fn_def[:marker] || !valid
            fn_def[:marker] = Element.new(:footnote, fn_def[:content], nil, :name => @src[1])
            fn_def[:stack] = [@stack.map {|s| s.first}, @tree, fn_def[:marker]].flatten.compact
            @tree.children << fn_def[:marker]
          else
            warning("Footnote marker '#{@src[1]}' already appeared in document, ignoring newly found marker")
            add_text(@src.matched)
          end
        else
          warning("Footnote definition for '#{@src[1]}' not found")
          add_text(@src.matched)
        end
      end
      define_parser(:footnote_marker, FOOTNOTE_MARKER_START, '\[')

    end
  end
end
