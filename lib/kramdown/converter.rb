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

  # This module contains all available converters, i.e. classes that take a root Element and convert
  # it to a specific output format. The result is normally a string. For example, the
  # Converter::Html module converts an element tree into valid HTML.
  #
  # Converters use the Base class for common functionality (like applying a template to the output)
  # \- see its API documentation for how to create a custom converter class.
  module Converter

    autoload :Base, 'kramdown/converter/base'
    autoload :Html, 'kramdown/converter/html'
    autoload :Latex, 'kramdown/converter/latex'
    autoload :Kramdown, 'kramdown/converter/kramdown'
    autoload :Toc, 'kramdown/converter/toc'
    autoload :RemoveHtmlTags, 'kramdown/converter/remove_html_tags'

  end

end
