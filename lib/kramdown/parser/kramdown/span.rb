# -*- coding: utf-8 -*-

require 'kramdown'

module Kramdown
  module Parser
    class Kramdown

      # Parse the span at the current location.
      def parse_span
        start_line_number = @src.current_line_number
        saved_pos = @src.save_pos

        span_start = /(?:\[\s*?)/
        result = @src.scan(span_start)
        stop_re = /(?:\s*?\])/

        el = Element.new(:span, nil, nil, :location => start_line_number)
        found = parse_spans(el, stop_re) do
          el.children.size > 0
        end

        if found
          @src.scan(stop_re)
          @tree.children << el
        else
          @src.revert_pos(saved_pos)
          @src.pos += result.length
          add_text(result)
        end
      end

    end
  end
end
