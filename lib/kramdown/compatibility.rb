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
# All the code in this file is backported from Ruby 1.8.7 sothat kramdown works under 1.8.5
#
# :stopdoc:

if RUBY_VERSION <= '1.8.6'
  require 'rexml/parsers/baseparser'
  module REXML
    module Parsers
      class BaseParser
        UNAME_STR= "(?:#{NCNAME_STR}:)?#{NCNAME_STR}" unless const_defined?(:UNAME_STR)
      end
    end
  end

  if !String.instance_methods.include?("start_with?")

    class String
      def start_with?(str)
        self[0, str.length] == str
      end
      def end_with?(str)
        self[-str.length, str.length] == str
      end
    end

  end

end
