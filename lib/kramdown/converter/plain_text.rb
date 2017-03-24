# -*- coding: utf-8 -*-
#
#--
# Copyright (C) 2009-2014 Thomas Leitner <t_leitner@gmx.at>
#
# This file is part of kramdown which is licensed under the MIT.
#++
#

module Kramdown

  module Converter

    # Converts tree to plain text. Removes all formatting and attributes.
    # This converter can be used to generate clean text for use in meta tags,
    # plain text emails, etc.
    class PlainText < Base

      TEXT_TYPES ||= [
        :smart_quote,
        :typographic_sym,
        :entity,
        :text
      ].freeze

      def initialize(root, options)
        super
        @plain_text = "" # bin for plain text
      end

      def convert(el)
        type = el.type
        category = ::Kramdown::Element.category(el)

        @plain_text << convert_type(type, el) if TEXT_TYPES.include?(type)
        @plain_text << "\n" if category == :block

        el.children.each { |e| convert(e) }

        @plain_text.strip if type == :root
      end

      def convert_type(type, el)
        send("convert_#{type}", el)
      end

      def convert_text(el)
        el.value
      end

      def convert_entity(el)
        el.value.char
      end

      def convert_smart_quote(el)
        smart_quote_entity(el).char
      end

      def convert_typographic_sym(el)
        ::Kramdown::Converter::Html::TYPOGRAPHIC_SYMS[el.value]
          .map(&:char)
          .join("")
      end
    end
  end
end
