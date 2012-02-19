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
  module Parser
    class Kramdown

      if RUBY_VERSION == '1.8.5'
        ACHARS = '\w\x80-\xFF'
      elsif RUBY_VERSION < '1.9.0'
        ACHARS = '\w'
      else
        ACHARS = '[[:alnum:]]'
      end
      AUTOLINK_START_STR = "<((mailto|https?|ftps?):.+?|[-.#{ACHARS}]+@[-#{ACHARS}]+(?:\.[-#{ACHARS}]+)*\.[a-z]+)>"
      if RUBY_VERSION < '1.9.0'
        AUTOLINK_START = /#{AUTOLINK_START_STR}/u
      else
        AUTOLINK_START = /#{AUTOLINK_START_STR}/
      end

      # Parse the autolink at the current location.
      def parse_autolink
        @src.pos += @src.matched_size
        href = (@src[2].nil? ? "mailto:#{@src[1]}" : @src[1])
        el = Element.new(:a, nil, {'href' => href})
        add_text(@src[1].sub(/^mailto:/, ''), el)
        @tree.children << el
      end
      define_parser(:autolink, AUTOLINK_START, '<')

    end
  end
end
