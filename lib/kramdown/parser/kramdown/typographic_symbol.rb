# -*- coding: utf-8 -*-
#
#--
# Copyright (C) 2009-2013 Thomas Leitner <t_leitner@gmx.at>
#
# This file is part of kramdown which is licensed under the MIT.
#++
#

module Kramdown
  module Parser
    class Kramdown

      TYPOGRAPHIC_SYMS = [['---', :mdash], ['--', :ndash], ['...', :hellip],
                          ['\\<<', '&lt;&lt;'], ['\\>>', '&gt;&gt;'],
                          ['<< ', :laquo_space], [' >>', :raquo_space],
                          ['<<', :laquo], ['>>', :raquo]]
      TYPOGRAPHIC_SYMS_SUBST = Hash[*TYPOGRAPHIC_SYMS.flatten]
      TYPOGRAPHIC_SYMS_RE = /#{TYPOGRAPHIC_SYMS.map {|k,v| Regexp.escape(k)}.join('|')}/

      # Parse the typographic symbols at the current location.
      def parse_typographic_syms
        @src.pos += @src.matched_size
        val = TYPOGRAPHIC_SYMS_SUBST[@src.matched]
        if val.kind_of?(Symbol)
          @tree.children << Element.new(:typographic_sym, val)
        elsif @src.matched == '\\<<'
          @tree.children << Element.new(:entity, ::Kramdown::Utils::Entities.entity('lt'))
          @tree.children << Element.new(:entity, ::Kramdown::Utils::Entities.entity('lt'))
        else
          @tree.children << Element.new(:entity, ::Kramdown::Utils::Entities.entity('gt'))
          @tree.children << Element.new(:entity, ::Kramdown::Utils::Entities.entity('gt'))
        end
      end
      define_parser(:typographic_syms, TYPOGRAPHIC_SYMS_RE, '--|\\.\\.\\.|(?:\\\\| )?(?:<<|>>)')

    end
  end
end
