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

module Kramdown

  module Utils

    # A very simple class mimicking the most used methods of a Hash. The difference to a normal Hash
    # is that a OrderedHash retains the insertion order of the keys.
    class OrderedHash

      include Enumerable

      # Direct access to the hash with the key-value pairs. May not be used to modify the data!
      attr_reader :data

      # Initialize the OrderedHash object, optionally with an +hash+. If the optional +hash+ is
      # used, there is no special order imposed on the keys (additionally set keys will be stored in
      # insertion order). An OrderedHash object may be used instead of a hash to provide the initial
      # data.
      def initialize(hash = {})
        if hash.kind_of?(OrderedHash)
          @data, @order = hash.instance_eval { [@data.dup, @order.dup] }
        else
          @data = hash || {}
          @order = @data.keys
        end
      end

      # Iterate over the stored keys in insertion order.
      def each
        @order.each {|k| yield(k, @data[k])}
      end

      # Return the value for the +key+.
      def [](key)
        @data[key]
      end

      # Set the value for the +key+ to +val+.
      def []=(key, val)
        @order << key if !@data.has_key?(key)
        @data[key] = val
      end

      # Delete the +key+.
      def delete(key)
        @order.delete(key)
        @data.delete(key)
      end

      def inspect #:nodoc:
        "{" + map {|k,v| "#{k.inspect}=>#{v.inspect}"}.join(" ") + "}"
      end

    end

  end

end
