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

require 'kramdown/parser/kramdown/attribute_list'
require 'kramdown/parser/kramdown/blank_line'
require 'kramdown/parser/kramdown/eob'

module Kramdown
  module Parser
    class Kramdown

      BLOCK_BOUNDARY = /#{BLANK_LINE}|#{EOB_MARKER}|#{IAL_BLOCK_START}|\Z/

      # Return +true+ if we are after a block boundary.
      def after_block_boundary?
        !@tree.children.last || @tree.children.last.type == :blank ||
          (@tree.children.last.type == :eob && @tree.children.last.value.nil?) || @block_ial
      end

      # Return +true+ if we are before a block boundary.
      def before_block_boundary?
        @src.check(BLOCK_BOUNDARY)
      end

    end
  end
end
