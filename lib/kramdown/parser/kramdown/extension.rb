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

require 'kramdown/parser/kramdown/attribute_list'

module Kramdown
  module Parser
    class Kramdown

      EXT_BLOCK_START_STR = "^#{OPT_SPACE}\\{::(%s):(:)?(#{ALD_ANY_CHARS}*)\\}\s*?\n"
      EXT_BLOCK_START = /#{EXT_BLOCK_START_STR % ALD_ID_NAME}/

      # Parse the extension block at the current location.
      def parse_extension_block
        @src.pos += @src.matched_size

        ext = @src[1]
        opts = {}
        body = nil
        parse_attribute_list(@src[3], opts)

        if !@doc.extension.public_methods.map {|m| m.to_s}.include?("parse_#{ext}")
          warning("No extension named '#{ext}' found - ignoring extension block")
          body = :invalid
        end

        if !@src[2]
          stop_re = /#{EXT_BLOCK_START_STR % ext}/
          if result = @src.scan_until(stop_re)
            parse_attribute_list(@src[3], opts)
            body = result.sub!(stop_re, '') if body != :invalid
          else
            body = :invalid
            warning("No ending line for extension block '#{ext}' found - ignoring extension block")
          end
        end

        @doc.extension.send("parse_#{ext}", self, opts, body) if body != :invalid

        true
      end
      define_parser(:extension_block, EXT_BLOCK_START)

    end
  end
end
