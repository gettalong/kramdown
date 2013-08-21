# -*- coding: utf-8 -*-

require 'kramdown/parser/kramdown'

module Kramdown
  module Parser
    class GFM < Kramdown::Parser::Kramdown

      def initialize(source, options)
        super
        i = @block_parsers.index(:codeblock_fenced)
        @block_parsers.delete(:codeblock_fenced)
        @block_parsers.insert(i, :codeblock_fenced_gfm)
      end

      FENCED_CODEBLOCK_MATCH = /^(([~`]){3,})\s*?(\w+)?\s*?\n(.*?)^\1\2*\s*?\n/m

      define_parser(:codeblock_fenced_gfm, /^[~`]{3,}/, nil, 'parse_codeblock_fenced')

      def parse_paragraph
        result = @src.scan(PARAGRAPH_MATCH)
        while !@src.match?(self.class::PARAGRAPH_END)
          result << @src.scan(PARAGRAPH_MATCH)
        end
        result.chomp!
        unless @tree.children.last && @tree.children.last.type == :p
          @tree.children << new_block_el(:p)
        end
        lines = result.lstrip.split(/\n/)
        lines.each_with_index do |line, index|
          @tree.children.last.children << Element.new(@text_type, line) << Element.new(:br) << Element.new(@text_type, "\n")
        end
        @tree.children.last.children.pop # added one \n too many
        @tree.children.last.children.pop # added one :br too many
        true
      end

    end
  end
end
