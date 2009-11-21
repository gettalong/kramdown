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
  module Parser

    # A small helper class for storing block and span level parser methods by name.
    class Registry

      # Holds all the needed data for one block/span level parser.
      Data = Struct.new(:name, :type, :start_re, :module, :method)

      @@parsers = {}

      # Add a parser method
      #
      # * of type +type+ (can either be <tt>:block</tt> or <tt>:span</tt>),
      # * with the given +name+,
      # * defined in the module +mod_nam+
      # * and using +start_re+ as start
      #
      # to the registry. The method name is automatically derived from the +name+ or can explicitly
      # be set by using the +meth_name+ parameter.
      def self.define_parser(type, name, start_re, mod_name, meth_name = "parse_#{name}")
        raise "A parser with the name #{name} already exists!" if @@parsers.has_key?(name)
        @@parsers[name] = Data.new(name, type, start_re, mod_name, meth_name)
      end

      # Return the Data structure for the parser +name+.
      def self.parser(name = nil)
        @@parsers[name]
      end

      # Return +true+ if the Registry has a parser called +name+ of type +type+ (the usage of the
      # type is optional).
      def self.has_parser?(name, type = nil)
        @@parsers[name] && (type.nil? || @@parsers[name].type == type)
      end

    end

  end
end
