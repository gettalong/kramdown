# -*- coding: utf-8 -*-
#
#--
# Copyright (C) 2009-2015 Thomas Leitner <t_leitner@gmx.at>
#
# This file is part of kramdown which is licensed under the MIT.
#++
#


require 'kramdown/parser'

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
        end

        i = @span_parsers.index(:escaped_chars)
        @span_parsers[i] = :escaped_chars_gfm if i
        @span_parsers << :strikethrough_gfm
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
              new_element_options = { :location => child.options[:location] + index }

              children << Element.new(:text, (index > 0 ? "\n#{line}" : line), nil, new_element_options)
              children << Element.new(:br, nil, nil, new_element_options) if index < lines.size - 2 ||
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

      FENCED_CODEBLOCK_MATCH = /^(([~`]){3,})\s*?((\S+)(?:\?\S*)?)?\s*?\n(.*?)^\1\2*\s*?\n/m
      define_parser(:codeblock_fenced_gfm, /^[~`]{3,}/, nil, 'parse_codeblock_fenced')

      STRIKETHROUGH_DELIM = /~~/
      STRIKETHROUGH_MATCH = /#{STRIKETHROUGH_DELIM}[^\s~](.*?)[^\s~]#{STRIKETHROUGH_DELIM}/m
      define_parser(:strikethrough_gfm, STRIKETHROUGH_MATCH, '~~')

      def parse_strikethrough_gfm
        line_number = @src.current_line_number

        @src.pos += @src.matched_size
        el = Element.new(:html_element, 'del', {}, :category => :span, :line => line_number)
        @tree.children << el

        env = save_env
        reset_env(:src => Kramdown::Utils::StringScanner.new(@src.matched[2..-3], line_number),
                  :text_type => :text)
        parse_spans(el)
        restore_env(env)

        el
      end

      ESCAPED_CHARS_GFM = /\\([\\.*_+`<>()\[\]{}#!:\|"'\$=\-~])/
      define_parser(:escaped_chars_gfm, ESCAPED_CHARS_GFM, '\\\\', :parse_escaped_chars)

    end
  end
end
