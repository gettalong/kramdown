# -*- coding: utf-8 -*-
#
#--
# Copyright (C) 2009-2014 Thomas Leitner <t_leitner@gmx.at>
#
# This file is part of kramdown which is licensed under the MIT.
#++
#

module Kramdown::Converter::SyntaxHighlighter

  # Uses Rouge which is CSS-compatible to Pygments to highlight code blocks and code spans.
  module Rouge

    begin
      require 'rouge'

      # Highlighting via Rouge is available if this constant is +true+.
      AVAILABLE = true
    rescue LoadError, SyntaxError
      AVAILABLE = false  # :nodoc:
    end

    def self.call(converter, text, lang, type, _unused_opts)
      opts = converter.options[:syntax_highlighter_opts].dup
      lexer = ::Rouge::Lexer.find_fancy(lang || opts[:default_lang], text)
      return nil unless lexer

      opts[:wrap] = false if type == :span

      formatter = ::Rouge::Formatters::HTML.new(opts)
      formatter.format(lexer.lex(text))
    end

  end

end
