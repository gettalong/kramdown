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

  module Utils

    if RUBY_VERSION < '1.9'

      # A partial hash implementation which preserves the insertion order of the keys.
      #
      # *Note* that this class is only used on Ruby 1.8 since the built-in Hash on Ruby 1.9
      # automatically preserves the insertion order. However, to remain compatibility only the
      # methods defined in this class may be used when working with OrderedHash on Ruby 1.9.
      class OrderedHash

        include Enumerable

        # Initialize the OrderedHash object.
        def initialize
          @data =  {}
          @order = []
        end

        # Iterate over the stored keys in insertion order.
        def each
          @order.each {|k| yield(k, @data[k])}
        end

        # Return the value for the +key+.
        def [](key)
          @data[key]
        end

        # Return +true+ if the hash contains the key.
        def has_key?(key)
          @data.has_key?(key)
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

        def merge!(other)
          other.each {|k,v| self[k] = v}
          self
        end

        def dup #:nodoc:
          new_object = super
          new_object.instance_variable_set(:@data, @data.dup)
          new_object.instance_variable_set(:@order, @order.dup)
          new_object
        end

        def ==(other) #:nodoc:
          return false unless other.kind_of?(self.class)
          @data == other.instance_variable_get(:@data) && @order == other.instance_variable_get(:@order)
        end

        def inspect #:nodoc:
          "{" + map {|k,v| "#{k.inspect}=>#{v.inspect}"}.join(" ") + "}"
        end

      end

    else
      OrderedHash = Hash
    end

  end

end
