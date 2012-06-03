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

  module Converter

    # Removes all block (and optionally span) level HTML tags from the element tree.
    #
    # This converter can be used on parsed HTML documents to get an element tree that will only
    # contain native kramdown elements.
    #
    # *Note* that the returned element tree may not be fully conformant (i.e. the content models of
    # *some elements may be violated)!
    #
    # This converter modifies the given tree in-place and returns it.
    class RemoveHtmlTags < Base

      def initialize(root, options)
        super
        @options[:template] = ''
      end

      def convert(el)
        children = el.children.dup
        index = 0
        while index < children.length
          if [:xml_pi].include?(children[index].type) ||
              (children[index].type == :html_element && %w[style script].include?(children[index].value))
            children[index..index] = []
          elsif children[index].type == :html_element &&
            ((@options[:remove_block_html_tags] && children[index].options[:category] == :block) ||
             (@options[:remove_span_html_tags] && children[index].options[:category] == :span))
            children[index..index] = children[index].children
          else
            convert(children[index])
            index += 1
          end
        end
        el.children = children
        el
      end

    end

  end
end
