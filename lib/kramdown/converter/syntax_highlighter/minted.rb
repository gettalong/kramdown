# -*- coding: utf-8 -*-
#
#--
# Copyright (C) 2009-2015 Thomas Leitner <t_leitner@gmx.at>
#
# This file is part of kramdown which is licensed under the MIT.
#++
#

module Kramdown::Converter::SyntaxHighlighter

  # Uses Minted to highlight code blocks and code spans.
  module Minted

    # Highlighting via minted is always avaliable
    AVAILABLE = true

    def self.call(converter, text, lang, type, _opts)
      opts = converter.options[:syntax_highlighter_opts].dup

      # Fallback to default language
      lang ||= opts[:default_lang]

      options = []
      options << "breaklines" if opts[:wrap]
      options << "linenos" if opts[:line_numbers]
      frame = opts[:frame]
      options << "frame=#{frame}" if frame

      case type
      when :block
        "\\begin{minted}[#{options.join(',')}]{#{lang}}\n#{text}\n\\end{minted}"
      when :span 
        "\\mintinline{#{lang}}{#{text}}"
      else
        nil
      end
    end
  end
end
