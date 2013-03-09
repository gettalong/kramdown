# -*- coding: utf-8 -*-
#
#--
# Copyright (C) 2009-2013 Thomas Leitner <t_leitner@gmx.at>
#
# This file is part of kramdown which is licensed under the MIT.
#++
#

module Kramdown
  module Parser
    class Kramdown

      HR_START = /^#{OPT_SPACE}(\*|-|_)[ \t]*\1[ \t]*\1(\1|[ \t])*\n/

      # Parse the horizontal rule at the current location.
      def parse_horizontal_rule
        @src.pos += @src.matched_size
        @tree.children << new_block_el(:hr)
        true
      end
      define_parser(:horizontal_rule, HR_START)

    end
  end
end
