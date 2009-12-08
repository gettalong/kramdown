# -*- coding: utf-8 -*-
#
#--
# Copyright (C) 2009 Thomas Leitner <t_leitner@gmx.at>
#
# This file is part of kramdown.
#
# kramdown is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#++
#

require 'rexml/parsers/baseparser'

module Kramdown

  # This module contains all available converters, i.e. classes that take a document and convert the
  # document tree to a string in a specific format, for example, HTML.
  module Converter

    # Converts a Kramdown::Document to HTML.
    class Html

      # Initialize the HTML converter with the given Kramdown document +doc+.
      def initialize(doc)
        @doc = doc
        @footnote_counter = @footnote_start = @doc.options[:footnote_nr]
        @footnotes = []
      end
      private_class_method(:new, :allocate)

      # Convert the Kramdown document +doc+ to HTML.
      def self.convert(doc)
        new(doc).convert(doc.tree)
      end

      # Convert the element tree +el+, setting the indentation level to +indent+.
      def convert(el, indent = -2)
        result = ''
        el.children.each do |inner_el|
          result << convert(inner_el, indent + 2)
        end
        send("convert_#{el.type}", el, result, indent)
      end

      def convert_blank(el, inner, indent)
        "\n"
      end

      def convert_text(el, inner, indent)
        escape_html(el.value, false)
      end

      def convert_eob(el, inner, indent)
        ''
      end

      def convert_p(el, inner, indent)
        "#{' '*indent}<p#{options_for_element(el)}>#{inner}</p>\n"
      end

      def convert_codeblock(el, inner, indent)
        result = escape_html(el.value)
        if el.options[:attr] && el.options[:attr].has_key?('class') && el.options[:attr]['class'] =~ /\bshow-whitespaces\b/
          result.gsub!(/(?:(^[ \t]+)|([ \t]+$)|([ \t]+))/) do |m|
            suffix = ($1 ? '-l' : ($2 ? '-r' : ''))
            m.scan(/./).map do |c|
              case c
              when "\t" then "<span class=\"ws-tab#{suffix}\">\t</span>"
              when " " then "<span class=\"ws-space#{suffix}\">&sdot;</span>"
              end
            end.join('')
          end
        end
        "#{' '*indent}<pre#{options_for_element(el)}><code>#{result}#{result =~ /\n\Z/ ? '' : "\n"}</code></pre>\n"
      end

      def convert_blockquote(el, inner, indent)
        "#{' '*indent}<blockquote#{options_for_element(el)}>\n#{inner}#{' '*indent}</blockquote>\n"
      end

      def convert_header(el, inner, indent)
        "#{' '*indent}<h#{el.options[:level]}#{options_for_element(el)}>#{inner}</h#{el.options[:level]}>\n"
      end

      def convert_hr(el, inner, indent)
        "#{' '*indent}<hr />\n"
      end

      def convert_ul(el, inner, indent)
        "#{' '*indent}<#{el.type}#{options_for_element(el)}>\n#{inner}#{' '*indent}</#{el.type}>\n"
      end
      alias :convert_ol :convert_ul
      alias :convert_dl :convert_ul

      def convert_li(el, inner, indent)
        output = ' '*indent << "<#{el.type}" << options_for_element(el) << ">"
        if el.options[:first_is_block]
          output << "\n" << inner << ' '*indent
        else
          output << inner << (inner =~ /\n\Z/ ? ' '*indent : '')
        end
        output << "</#{el.type}>\n"
      end
      alias :convert_dd :convert_li

      def convert_dt(el, inner, indent)
        "#{' '*indent}<dt#{options_for_element(el)}>#{inner}</dt>\n"
      end

      def convert_html_raw(el, inner, indent)
        el.value + (el.options[:type] == :block ? "\n" : '')
      end

      HTML_TAGS_WITH_BODY=['div', 'script']

      def convert_html_element(el, inner, indent)
        if @doc.options[:filter_html].include?(el.value)
          inner.chomp + (el.options[:type] == :block ? "\n" : '')
        elsif el.options[:type] == :span
          "<#{el.value}#{options_for_element(el)}" << (!inner.empty? ? ">#{inner}</#{el.value}>" : " />")
        else
          output = ''
          output << ' '*indent if !el.options[:no_start_indent] && el.options[:parse_type] != :raw && !el.options[:parent_is_raw]
          output << "<#{el.value}#{options_for_element(el)}"
          if !inner.empty? && (el.options[:compact] || el.options[:parse_type] != :block)
            output << ">#{inner}</#{el.value}>"
          elsif !inner.empty? && (el.children.first.type == :text || el.children.first.options[:no_start_indent])
            output << ">#{inner}" << ' '*indent << "</#{el.value}>"
          elsif !inner.empty?
            output << ">\n#{inner}"  << ' '*indent << "</#{el.value}>"
          elsif HTML_TAGS_WITH_BODY.include?(el.value)
            output << "></#{el.value}>"
          else
            output << " />"
          end
          output << "\n" if el.options[:outer_element] || (el.options[:parse_type] != :raw && !el.options[:parent_is_raw])
          output
        end
      end

      def convert_br(el, inner, indent)
        "<br />"
      end

      def convert_a(el, inner, indent)
        if el.options[:attr]['href'] =~ /^mailto:/
          el = Marshal.load(Marshal.dump(el)) # so that the original is not changed
          href = obfuscate(el.options[:attr]['href'].sub(/^mailto:/, ''))
          mailto = obfuscate('mailto')
          el.options[:attr]['href'] = "#{mailto}:#{href}"
        end
        inner = obfuscate(inner) if el.options[:obfuscate_text]
        "<a#{options_for_element(el)}>#{inner}</a>"
      end

      def convert_img(el, inner, indent)
        "<img#{options_for_element(el)} />"
      end

      def convert_codespan(el, inner, indent)
        "<code#{options_for_element(el)}>#{escape_html(el.value)}</code>"
      end

      def convert_footnote(el, inner, indent)
        number = @footnote_counter
        @footnote_counter += 1
        @footnotes << [el.options[:name], @doc.parse_infos[:footnotes][el.options[:name]]]
        "<sup id=\"fnref:#{el.options[:name]}\"><a href=\"#fn:#{el.options[:name]}\" rel=\"footnote\">#{number}</a></sup>"
      end

      def convert_raw(el, inner, indent)
        el.value
      end

      def convert_em(el, inner, indent)
        "<#{el.type}#{options_for_element(el)}>#{inner}</#{el.type}>"
      end
      alias :convert_strong :convert_em

      def convert_entity(el, inner, indent)
        el.value
      end

      TYPOGRAPHIC_SYMS = {
        :mdash => '&mdash;', :ndash => '&ndash;', :ellipsis => '&hellip;',
        :laquo_space => '&laquo;&nbsp;', :raquo_space => '&nbsp;&raquo;',
        :laquo => '&laquo;', :raquo => '&raquo;'
      }
      def convert_typographic_sym(el, inner, indent)
        TYPOGRAPHIC_SYMS[el.value]
      end

      def convert_root(el, inner, indent)
        inner << footnote_content
      end

      # Helper method for obfuscating the +text+ by using HTML entities.
      def obfuscate(text)
        result = ""
        text.each_byte do |b|
          result += (b > 128 ? b.chr : "&#%03d;" % b)
        end
        result
      end

      # Return a HTML list with the footnote content for the used footnotes.
      def footnote_content
        ol = Element.new(:ol)
        ol.options[:attr] = {'start' => @footnote_start} if @footnote_start != 1
        @footnotes.each do |name, data|
          li = Element.new(:li, nil, {:attr => {:id => "fn:#{name}"}, :first_is_block => true})
          li.children = Marshal.load(Marshal.dump(data[:content].children)) #TODO: probably remove this!!!!
          ol.children << li

          ref = Element.new(:raw, "<a href=\"#fnref:#{name}\" rev=\"footnote\">&#8617;</a>")
          if li.children.last.type == :p
            para = li.children.last
          else
            li.children << (para = Element.new(:p))
          end
          para.children << ref
        end
        (ol.children.empty? ? '' : "<div class=\"kramdown-footnotes\">\n#{convert(ol, 2)}</div>\n")
      end

      # Return the string with the attributes of the element +el+.
      def options_for_element(el)
        (el.options[:attr] || {}).map {|k,v| v.nil? ? '' : " #{k}=\"#{escape_html(v.to_s, false)}\"" }.sort.join('')
      end

      ESCAPE_MAP = {
        '<' => '&lt;',
        '>' => '&gt;',
        '"' => '&quot;',
        '&' => '&amp;'
      }
      ESCAPE_ALL_RE = Regexp.union(*ESCAPE_MAP.collect {|k,v| Regexp.escape(k)})
      ESCAPE_ALL_NOT_ENTITIES_RE = Regexp.union(REXML::Parsers::BaseParser::REFERENCE_RE, ESCAPE_ALL_RE)

      # Escape the special HTML characters in the string +str+. If +all+ is +true+ then all
      # characters are escaped, if +all+ is +false+ then only those characters are escaped that are
      # not part on an HTML entity.
      def escape_html(str, all = true)
        str.gsub(all ? ESCAPE_ALL_RE : ESCAPE_ALL_NOT_ENTITIES_RE) {|m| ESCAPE_MAP[m] || m}
      end

    end

  end
end
