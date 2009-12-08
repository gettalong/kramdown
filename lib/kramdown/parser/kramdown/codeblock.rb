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
  module Parser
    class Kramdown

      CODEBLOCK_START = INDENT
      CODEBLOCK_MATCH = /(?:#{INDENT}.*?\S.*?\n)+/

      # Parse the indented codeblock at the current location.
      def parse_codeblock
        result = @src.scan(CODEBLOCK_MATCH).gsub(INDENT, '')
        children = @tree.children
        if children.length >= 2 && children[-1].type == :blank && children[-2].type == :codeblock
          children[-2].value << children[-1].value.gsub(INDENT, '') << result
          children.pop
        else
          @tree.children << Element.new(:codeblock, result)
        end
        true
      end
      define_parser(:codeblock, CODEBLOCK_START)


      FENCED_CODEBLOCK_START = /^~{3,}/
      FENCED_CODEBLOCK_MATCH = /^(~{3,})\s*?\n(.*?)^\1~*\s*?\n/m

      # Parse the fenced codeblock at the current location.
      def parse_codeblock_fenced
        if @src.check(FENCED_CODEBLOCK_MATCH)
          @src.pos += @src.matched_size
          @tree.children << Element.new(:codeblock, @src[2])
          true
        else
          false
        end
      end
      define_parser(:codeblock_fenced, FENCED_CODEBLOCK_START)

    end
  end
end
