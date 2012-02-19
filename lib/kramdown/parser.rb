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

  # This module contains all available parsers. A parser takes an input string and converts the
  # string to an element tree.
  #
  # New parsers should be derived from the Base class which provides common functionality - see its
  # API documentation for how to create a custom converter class.
  module Parser

    autoload :Base, 'kramdown/parser/base'
    autoload :Kramdown, 'kramdown/parser/kramdown'
    autoload :Html, 'kramdown/parser/html'
    autoload :Markdown, 'kramdown/parser/markdown'

  end

end
