# -*- coding: utf-8 -*-

require 'kramdown/parser'

module Kramdown
  module Parser
    class SmartyPants < Kramdown::Parser::Kramdown

      def initialize(source, options)
        super
        @block_parsers = [:block_html]
        @span_parsers =  [:smart_quotes, :html_entity, :typographic_syms, :span_html]
      end

    end
  end
end
