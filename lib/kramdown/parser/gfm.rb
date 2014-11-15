# -*- coding: utf-8 -*-

require 'kramdown/parser/kramdown'

module Kramdown
  module Parser
    class GFM < Kramdown::Parser::Kramdown

      def initialize(source, options)
        super
        @span_parsers.delete(:line_break) if @options[:hard_wrap]
        {:codeblock_fenced => :codeblock_fenced_gfm,
          :atx_header => :atx_header_gfm}.each do |current, replacement|
          i = @block_parsers.index(current)
          @block_parsers.delete(current)
          @block_parsers.insert(i, replacement)

          i = @span_parsers.index(:escaped_chars)
          @span_parsers[i] = :escaped_chars_gfm if i

          @span_parsers << :strikethrough_gfm
        end
      end

      def parse
        super
        add_hard_line_breaks(@root) if @options[:hard_wrap]
      end

      def add_hard_line_breaks(element)
        element.children.map! do |child|
          if child.type == :text && child.value =~ /\n/
            children = []
            lines = child.value.split(/\n/, -1)
            omit_trailing_br = (Kramdown::Element.category(element) == :block && element.children[-1] == child &&
                lines[-1].empty?)
            lines.each_with_index do |line, index|
              children << Element.new(:text, (index > 0 ? "\n#{line}" : line))
              children << Element.new(:br) if index < lines.size - 2 ||
                  (index == lines.size - 2 && !omit_trailing_br)
            end
            children
          elsif child.type == :html_element
            child
          else
            add_hard_line_breaks(child)
            child
          end
        end.flatten!
      end

      ATX_HEADER_START = /^\#{1,6}\s/
      define_parser(:atx_header_gfm, ATX_HEADER_START, nil, 'parse_atx_header')

      FENCED_CODEBLOCK_MATCH = /^(([~`]){3,})\s*?(\w+)?\s*?\n(.*?)^\1\2*\s*?\n/m
      define_parser(:codeblock_fenced_gfm, /^[~`]{3,}/, nil, 'parse_codeblock_fenced')

      STRIKETHROUGH_DELIM = /~{2,}/
      STRIKETHROUGH_MATCH = /#{STRIKETHROUGH_DELIM}[^~]+#{STRIKETHROUGH_DELIM}/
      define_parser(:strikethrough_gfm, STRIKETHROUGH_MATCH, nil)

      def parse_strikethrough_gfm
        line_number = @src.current_line_number

        if @src.scan(STRIKETHROUGH_DELIM)
          el = Element.new(:html_element, 'del', {}, category: :span, line: line_number)
          @tree.children << el
          parse_spans(el, STRIKETHROUGH_DELIM)
          @src.scan(STRIKETHROUGH_DELIM)
        end
      end

      ESCAPED_CHARS_GFM = /\\([\\.*_+`<>()\[\]{}#!:\|"'\$=\-~])/

      # Parse the backslash-escaped character at the current location.
      def parse_escaped_chars_gfm
        @src.pos += @src.matched_size
        add_text(@src[1])
      end

      define_parser(:escaped_chars_gfm, ESCAPED_CHARS_GFM, '\\\\')
    end
  end
end