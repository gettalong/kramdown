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

require 'rexml/parsers/baseparser'

module Kramdown

  module Converter

    # Converts a Kramdown::Document to an element tree that represents the table of contents.
    #
    # The returned tree consists of Element objects of type :toc where the root element is just used
    # as container object. Each :toc element contains as value the wrapped :header element and under
    # the attribute key :id the header ID that should be used (note that this ID may not exist in
    # the wrapped element).
    #
    # Since the TOC tree consists of special :toc elements, one cannot directly feed this tree to
    # other converters!
    class Toc < Base

      def initialize(root, options)
        super
        @toc = Element.new(:toc)
        @stack = []
        @options[:template] = ''
      end

      def convert(el)
        if el.type == :header && in_toc?(el)
          attr = el.attr.dup
          attr['id'] = generate_id(el.options[:raw_text]) if @options[:auto_ids] && !attr['id']
          add_to_toc(el, attr['id'], @toc) if attr['id']
        else
          el.children.each {|child| convert(child)}
        end
        @toc
      end

      private

      def add_to_toc(el, id, toc)
        toc_element = Element.new(:toc, el, :id => id)

        success = false
        while !success
          if @stack.empty?
            @toc.children << toc_element
            @stack << toc_element
            success = true
          elsif @stack.last.value.options[:level] < el.options[:level]
            @stack.last.children << toc_element
            @stack << toc_element
            success = true
          else
            @stack.pop
          end
        end
      end

    end

  end
end
