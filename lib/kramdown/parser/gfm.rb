# -*- coding: utf-8 -*-

require 'kramdown/parser/kramdown'

module Kramdown
  module Parser
    class GFM < Kramdown::Parser::Kramdown

      def initialize(source, options)
        super
        @span_parsers.delete(:line_break)
        i = @block_parsers.index(:codeblock_fenced)
        @block_parsers.delete(:codeblock_fenced)
        @block_parsers.insert(i, :codeblock_fenced_gfm)
      end

      def parse
        super
        add_hard_line_breaks(@root) if @options[:hard_wrap]
      end

      def add_hard_line_breaks(element)
        element.children.map! do |child|
          if child.type == :text && child.value =~ /\n/
            children = []
            lines = child.value.split(/\n(?=.)/)
            lines.each_with_index do |line, index|
              children << Element.new(:text, (index > 0 ? "\n#{line}" : line))
              children << Element.new(:br) if index < lines.size - 1
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

      FENCED_CODEBLOCK_MATCH = /^(([~`]){3,})\s*?(\w+)?\s*?\n(.*?)^\1\2*\s*?\n/m

      define_parser(:codeblock_fenced_gfm, /^[~`]{3,}/, nil, 'parse_codeblock_fenced')

    end
  end
end
