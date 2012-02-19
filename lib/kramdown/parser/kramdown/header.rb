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

require 'kramdown/parser/kramdown/block_boundary'

module Kramdown
  module Parser
    class Kramdown

      HEADER_ID=/(?:[ \t]\{#(\w[\w-]*)\})?/
      SETEXT_HEADER_START = /^(#{OPT_SPACE}[^ \t].*?)#{HEADER_ID}[ \t]*?\n(-|=)+\s*?\n/

      # Parse the Setext header at the current location.
      def parse_setext_header
        return false if !after_block_boundary?

        @src.pos += @src.matched_size
        text, id, level = @src[1], @src[2], @src[3]
        text.strip!
        el = new_block_el(:header, nil, nil, :level => (level == '-' ? 2 : 1), :raw_text => text)
        add_text(text, el)
        el.attr['id'] = id if id
        @tree.children << el
        true
      end
      define_parser(:setext_header, SETEXT_HEADER_START)


      ATX_HEADER_START = /^\#{1,6}/
      ATX_HEADER_MATCH = /^(\#{1,6})(.+?)\s*?#*#{HEADER_ID}\s*?\n/

      # Parse the Atx header at the current location.
      def parse_atx_header
        return false if !after_block_boundary?

        @src.scan(ATX_HEADER_MATCH)
        level, text, id = @src[1], @src[2], @src[3]
        text.strip!
        el = new_block_el(:header, nil, nil, :level => level.length, :raw_text => text)
        add_text(text, el)
        el.attr['id'] = id if id
        @tree.children << el
        true
      end
      define_parser(:atx_header, ATX_HEADER_START)

    end
  end
end
