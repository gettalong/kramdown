# -*- coding: utf-8 -*-
#

module Kramdown
  module Parser
    class Kramdown

      SUPERSUB_START = /(\^|~)(?!\1)/

      # Parse the emphasis at the current location.
      def parse_supersub
        result = @src.scan(SUPERSUB_START)
        reset_pos = @src.pos
        char = @src[1]
        type = char == '^' ? :sup : :sub

        el = Element.new(type)
        stop_re = /#{Regexp.escape(char)}/
        found = parse_spans(el, stop_re)

        if found
          @src.scan(stop_re)
          @tree.children << el
        else
          @src.pos = reset_pos
          add_text(result)
        end
      end

      define_parser(:supersub, SUPERSUB_START, '\^|~')

    end
  end
end
