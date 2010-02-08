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
    class Kramdown

      # Generate an alpha-numeric ID from the the string +str+.
      def generate_id(str)
        gen_id = str.gsub(/[^a-zA-Z0-9 -]/, '').gsub(/^[^a-zA-Z]*/, '').gsub(' ', '-').downcase
        gen_id = 'section' if gen_id.length == 0
        @used_ids ||= {}
        if @used_ids.has_key?(gen_id)
          gen_id += '-' + (@used_ids[gen_id] += 1).to_s
        else
          @used_ids[gen_id] = 0
        end
        gen_id
      end

      HEADER_ID=/(?:[ \t]\{#((?:\w|\d)[\w\d-]*)\})?/
      SETEXT_HEADER_START = /^(#{OPT_SPACE}[^ \t].*?)#{HEADER_ID}[ \t]*?\n(-|=)+\s*?\n/

      # Parse the Setext header at the current location.
      def parse_setext_header
        if @tree.children.last && @tree.children.last.type != :blank
          return false
        end
        @src.pos += @src.matched_size
        text, id, level = @src[1].strip, @src[2], @src[3]
        el = Element.new(:header, nil, :level => (level == '-' ? 2 : 1))
        add_text(text, el)
        el.options[:attr] = {'id' => id} if id
        el.options[:attr] = {'id' => generate_id(text)} if @doc.options[:auto_ids] && !id
        @tree.children << el
        true
      end
      define_parser(:setext_header, SETEXT_HEADER_START)


      ATX_HEADER_START = /^\#{1,6}/
      ATX_HEADER_MATCH = /^(\#{1,6})(.+?)\s*?#*#{HEADER_ID}\s*?\n/

      # Parse the Atx header at the current location.
      def parse_atx_header
        if @tree.children.last && @tree.children.last.type != :blank
          return false
        end
        result = @src.scan(ATX_HEADER_MATCH)
        level, text, id = @src[1], @src[2].strip, @src[3]
        el = Element.new(:header, nil, :level => level.length)
        add_text(text, el)
        el.options[:attr] = {'id' => id} if id
        el.options[:attr] = {'id' => generate_id(text)} if @doc.options[:auto_ids] && !id
        @tree.children << el
        true
      end
      define_parser(:atx_header, ATX_HEADER_START)

    end
  end
end
