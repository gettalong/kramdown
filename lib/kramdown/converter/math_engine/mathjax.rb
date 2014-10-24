# -*- coding: utf-8 -*-
#
#--
# Copyright (C) 2009-2014 Thomas Leitner <t_leitner@gmx.at>
#
# This file is part of kramdown which is licensed under the MIT.
#++
#

module Kramdown::Converter::MathEngine

  # Uses the MathJax javascript library for displaying math.
  #
  # Note that the javascript library itself is not include or linked, this has to be done
  # separately. Only the math content is marked up correctly.
  module Mathjax

    def self.call(converter, el, opts)
      type = el.options[:category]
      text = (el.value =~ /<|&/ ? "% <![CDATA[\n#{el.value} %]]>" : el.value)
      text.gsub!(/<\/?script>?/, '')

      attr = {:type => "math/tex#{type == :block ? '; mode=display' : ''}"}
      if type == :block
        converter.format_as_block_html('script', attr, text, opts[:indent])
      else
        converter.format_as_span_html('script', attr, text)
      end
    end

  end

end
