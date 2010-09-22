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

require 'kramdown/parser/kramdown/block_boundary'

module Kramdown
  module Parser
    class Kramdown

      BLOCK_MATH_START = /^#{OPT_SPACE}(\\)?\$\$(.*?)\$\$\s*?\n/m

      # Parse the math block at the current location.
      def parse_block_math
        if !after_block_boundary?
          return false
        elsif @src[1]
          @src.scan(/^#{OPT_SPACE}\\/)
          return false
        end
        orig_pos = @src.pos
        @src.pos += @src.matched_size
        data = @src[2]
        if before_block_boundary?
          @tree.children << new_block_el(:math, data)
          true
        else
          @src.pos = orig_pos
          false
        end
      end
      define_parser(:block_math, BLOCK_MATH_START)


      INLINE_MATH_START = /\$\$(.*?)\$\$/

      # Parse the inline math at the current location.
      def parse_inline_math
        @src.pos += @src.matched_size
        @tree.children << Element.new(:math, @src[1], nil, :category => :span)
      end
      define_parser(:inline_math, INLINE_MATH_START, '\$')

    end
  end
end
