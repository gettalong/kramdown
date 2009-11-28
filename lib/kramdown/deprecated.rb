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

  class Extension

    def parse_nokramdown(parser, opts, body)
      warn("The extension 'nokramdown' is deprecated and has been renamed to 'nomarkdown'")
      parse_nomarkdown(parser, opts, body)
    end

    def parse_kdoptions(parser, opts, body)
      warn("The extension 'kdoptions' is deprecated and has been renamed to 'options'")
      parse_options(parser, opts, body)
    end

  end

end


