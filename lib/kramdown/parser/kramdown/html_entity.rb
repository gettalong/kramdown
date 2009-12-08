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

require 'rexml/parsers/baseparser'

module Kramdown
  module Parser
    class Kramdown

      # Parse the HTML entity at the current location.
      def parse_html_entity
        @src.pos += @src.matched_size
        @tree.children << Element.new(:entity, @src.matched)
      end
      define_parser(:html_entity, REXML::Parsers::BaseParser::REFERENCE_RE)


    end
  end
end
