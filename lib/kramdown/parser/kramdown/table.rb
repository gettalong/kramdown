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

require 'kramdown/parser/kramdown/block_boundary'

module Kramdown
  module Parser
    class Kramdown

      TABLE_SEP_LINE = /^([+|: -]*?-[+|: -]*?)[ \t]*\n/
      TABLE_HSEP_ALIGN = /[ ]?(:?)-+(:?)[ ]?/
      TABLE_FSEP_LINE = /^[+|: =]*?=[+|: =]*?[ \t]*\n/
      TABLE_ROW_LINE = /^(.*?)[ \t]*\n/
      TABLE_LINE = /(?:\||.*?[^\\\n]\|).*?\n/
      TABLE_START = /^#{OPT_SPACE}(?=\S)#{TABLE_LINE}/

      # Parse the table at the current location.
      def parse_table
        return false if !after_block_boundary?

        orig_pos = @src.pos
        table = new_block_el(:table, nil, nil, :alignment => [])
        leading_pipe = (@src.check(TABLE_LINE) =~ /^\s*\|/)
        @src.scan(TABLE_SEP_LINE)

        rows = []
        has_footer = false
        columns = 0

        add_container = lambda do |type, force|
          if force || type != :tbody || !has_footer
            cont = Element.new(type)
            cont.children, rows = rows, []
            table.children << cont
          end
        end

        while !@src.eos?
          break if !@src.check(TABLE_LINE)
          if @src.scan(TABLE_SEP_LINE) && !rows.empty?
            if table.options[:alignment].empty? && !has_footer
              add_container.call(:thead, false)
              table.options[:alignment] = @src[1].scan(TABLE_HSEP_ALIGN).map do |left, right|
                (left.empty? && right.empty? && :default) || (right.empty? && :left) || (left.empty? && :right) || :center
              end
            else # treat as normal separator line
              add_container.call(:tbody, false)
            end
          elsif @src.scan(TABLE_FSEP_LINE)
            add_container.call(:tbody, true) if !rows.empty?
            has_footer = true
          elsif @src.scan(TABLE_ROW_LINE)
            trow = Element.new(:tr)
            cells = (@src[1] + ' ').split(/\|/)
            i = 0
            while i < cells.length - 1
              backslashes = cells[i].scan(/\\+$/).first
              if backslashes && backslashes.length % 2 == 1
                cells[i] = cells[i].chop + '|' + cells[i+1]
                cells.delete_at(i+1)
              else
                i += 1
              end
            end
            cells.shift if leading_pipe && cells.first.strip.empty?
            cells.pop if cells.last.strip.empty?
            cells.each do |cell_text|
              tcell = Element.new(:td)
              tcell.children << Element.new(:raw_text, cell_text.strip)
              trow.children << tcell
            end
            columns = [columns, cells.length].max
            rows << trow
          else
            break
          end
        end

        if !before_block_boundary?
          @src.pos = orig_pos
          return false
        end

        add_container.call(has_footer ? :tfoot : :tbody, false) if !rows.empty?

        if !table.children.any? {|c| c.type == :tbody}
          warning("Found table without body - ignoring it")
          @src.pos = orig_pos
          return false
        end

        # adjust all table rows to have equal number of columns, same for alignment defs
        table.children.each do |kind|
          kind.children.each do |row|
            (columns - row.children.length).times do
              row.children << Element.new(:td)
            end
            row.children.each {|el| el.type = :th} if kind.type == :thead
          end
        end
        if table.options[:alignment].length > columns
          table.options[:alignment] = table.options[:alignment][0...columns]
        else
          table.options[:alignment] += [:default] * (columns - table.options[:alignment].length)
        end

        @tree.children << table

        true
      end
      define_parser(:table, TABLE_START)

    end
  end
end
