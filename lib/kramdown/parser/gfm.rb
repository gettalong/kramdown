module Kramdown
  module Parser
    class GFM < Kramdown::Parser::Kramdown

      def initialize(source, options)
        super
        @block_parsers.unshift(:gfm_codeblock_fenced)
      end

      GFM_FENCED_CODEBLOCK_START = /^`{3,}/
      GFM_FENCED_CODEBLOCK_MATCH = /^`{3,} *(\w+)?\s*?\n(.*?)^`{3,}\s*?\n/m

      # Parse the fenced codeblock at the current location.
      def parse_gfm_codeblock_fenced
        if @src.check(GFM_FENCED_CODEBLOCK_MATCH)
          @src.pos += @src.matched_size
          el = new_block_el(:codeblock, @src[2])
          lang = @src[1].to_s.strip
          el.attr['class'] = "language-#{lang}" unless lang.empty?
          @tree.children << el
          true
        else
          false
        end
      end
      define_parser(:gfm_codeblock_fenced, GFM_FENCED_CODEBLOCK_START)

      def parse_paragraph
        result = @src.scan(PARAGRAPH_MATCH)
        while !@src.match?(self.class::PARAGRAPH_END)
          result << @src.scan(PARAGRAPH_MATCH)
        end
        result.chomp!
        unless @tree.children.last && @tree.children.last.type == :p
          @tree.children << new_block_el(:p)
        end
        lines = result.lstrip.each_line.map {|line| Element.new(@text_type, line) }
        @tree.children.last.children << lines.first
        lines.drop(1).each do |line|
          @tree.children.last.children << Element.new(:br) << line
        end
        true
      end

    end
  end
end
