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

require 'kramdown/parser/kramdown/blank_line'
require 'kramdown/parser/kramdown/attribute_list'
require 'kramdown/parser/kramdown/eob'

module Kramdown
  module Parser
    class Kramdown

      BLOCKQUOTE_START = /^#{OPT_SPACE}> ?/
      BLOCKQUOTE_MATCH = /(^.*\n)+?(?=#{BLANK_LINE}|#{IAL_BLOCK_START}|#{EOB_MARKER}|^#{OPT_SPACE}#{LAZY_END_HTML_STOP}|^#{OPT_SPACE}#{LAZY_END_HTML_START}|\Z)/

      # Parse the blockquote at the current location.
      def parse_blockquote
        el = new_block_el(:blockquote)
        @tree.children << el
        parse_blocks(el, @src.scan(BLOCKQUOTE_MATCH).gsub!(BLOCKQUOTE_START, ''))
        true
      end
      define_parser(:blockquote, BLOCKQUOTE_START)


    end
  end
end
