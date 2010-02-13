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

  module Converter

    # Converts a Kramdown::Document to HTML.
    class Html < Base

      # :stopdoc:

      # Defines the amount of indentation used when nesting HTML tags.
      INDENTATION = 2

      begin
        require 'coderay'

        # Highlighting via coderay is available if this constant is +true+.
        HIGHLIGHTING_AVAILABLE = true
      rescue LoadError => e
        HIGHLIGHTING_AVAILABLE = false
      end

      # Initialize the HTML converter with the given Kramdown document +doc+.
      def initialize(doc)
        super
        @footnote_counter = @footnote_start = @doc.options[:footnote_nr]
        @footnotes = []
      end

      def convert(el, indent = -INDENTATION, opts = {})
        send("convert_#{el.type}", el, indent, opts)
      end

      def inner(el, indent, opts)
        result = ''
        indent += INDENTATION
        el.children.each do |inner_el|
          result << send("convert_#{inner_el.type}", inner_el, indent, opts)
        end
        result
      end

      def convert_blank(el, indent, opts)
        "\n"
      end

      def convert_text(el, indent, opts)
        escape_html(el.value, :text)
      end

      def convert_eob(el, indent, opts)
        ''
      end

      def convert_p(el, indent, opts)
        "#{' '*indent}<p#{options_for_element(el)}>#{inner(el, indent, opts)}</p>\n"
      end

      def convert_codeblock(el, indent, opts)
        if el.options[:attr] && el.options[:attr]['lang'] && HIGHLIGHTING_AVAILABLE
          el = Marshal.load(Marshal.dump(el)) # so that the original is not changed
          opts = {:wrap => @doc.options[:coderay_wrap], :line_numbers => @doc.options[:coderay_line_numbers],
            :line_number_start => @doc.options[:coderay_line_number_start], :tab_width => @doc.options[:coderay_tab_width],
            :bold_every => @doc.options[:coderay_bold_every], :css => @doc.options[:coderay_css]}
          result = CodeRay.scan(el.value, el.options[:attr].delete('lang').to_sym).html(opts).chomp + "\n"
          "#{' '*indent}<div#{options_for_element(el)}>#{result}#{' '*indent}</div>\n"
        else
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
      end

      def convert_blockquote(el, indent, opts)
        "#{' '*indent}<blockquote#{options_for_element(el)}>\n#{inner(el, indent, opts)}#{' '*indent}</blockquote>\n"
      end

      def convert_header(el, indent, opts)
        "#{' '*indent}<h#{el.options[:level]}#{options_for_element(el)}>#{inner(el, indent, opts)}</h#{el.options[:level]}>\n"
      end

      def convert_hr(el, indent, opts)
        "#{' '*indent}<hr />\n"
      end

      def convert_ul(el, indent, opts)
        "#{' '*indent}<#{el.type}#{options_for_element(el)}>\n#{inner(el, indent, opts)}#{' '*indent}</#{el.type}>\n"
      end
      alias :convert_ol :convert_ul
      alias :convert_dl :convert_ul

      def convert_li(el, indent, opts)
        output = ' '*indent << "<#{el.type}" << options_for_element(el) << ">"
        res = inner(el, indent, opts)
        if el.options[:first_is_block]
          output << "\n" << res << ' '*indent
        else
          output << res << (res =~ /\n\Z/ ? ' '*indent : '')
        end
        output << "</#{el.type}>\n"
      end
      alias :convert_dd :convert_li

      def convert_dt(el, indent, opts)
        "#{' '*indent}<dt#{options_for_element(el)}>#{inner(el, indent, opts)}</dt>\n"
      end

      HTML_TAGS_WITH_BODY=['div', 'script']

      def convert_html_element(el, indent, opts)
        res = inner(el, indent, opts)
        if @doc.options[:filter_html].include?(el.value)
          res.chomp + (el.options[:type] == :block ? "\n" : '')
        elsif el.options[:type] == :span
          "<#{el.value}#{options_for_element(el)}" << (!res.empty? ? ">#{res}</#{el.value}>" : " />")
        else
          output = ''
          output << ' '*indent if el.options[:parse_type] != :raw && !el.options[:parent_is_raw]
          output << "<#{el.value}#{options_for_element(el)}"
          if !res.empty? && el.options[:parse_type] != :block
            output << ">#{res}</#{el.value}>"
          elsif !res.empty?
            output << ">\n#{res}"  << ' '*indent << "</#{el.value}>"
          elsif HTML_TAGS_WITH_BODY.include?(el.value)
            output << "></#{el.value}>"
          else
            output << " />"
          end
          output << "\n" if el.options[:outer_element] || (el.options[:parse_type] != :raw && !el.options[:parent_is_raw])
          output
        end
      end

      def convert_html_text(el, indent, opts)
        escape_html(el.value, :text)
      end

      def convert_xml_comment(el, indent, opts)
        el.value + (el.options[:type] == :block ? "\n" : '')
      end
      alias :convert_xml_pi :convert_xml_comment

      def convert_table(el, indent, opts)
        if el.options[:alignment].all? {|a| a == :default}
          alignment = ''
        else
          alignment = el.options[:alignment].map do |a|
            "#{' '*(indent + INDENTATION)}" + (a == :default ? "<col />" : "<col align=\"#{a}\" />") + "\n"
          end.join('')
        end
        "#{' '*indent}<table#{options_for_element(el)}>\n#{alignment}#{inner(el, indent, opts)}#{' '*indent}</table>\n"
      end

      def convert_thead(el, indent, opts)
        opts[:cell_type] = case el.type
                           when :thead then 'th'
                           when :tbody, :tfoot then 'td'
                           else opts[:cell_type]
                           end
        "#{' '*indent}<#{el.type}#{options_for_element(el)}>\n#{inner(el, indent, opts)}#{' '*indent}</#{el.type}>\n"
      end
      alias :convert_tbody :convert_thead
      alias :convert_tfoot :convert_thead
      alias :convert_tr  :convert_thead

      def convert_td(el, indent, opts)
        res = inner(el, indent, opts)
        "#{' '*indent}<#{opts[:cell_type]}#{options_for_element(el)}>#{res.empty? ? "&nbsp;" : res}</#{opts[:cell_type]}>\n"
      end

      def convert_br(el, indent, opts)
        "<br />"
      end

      def convert_a(el, indent, opts)
        if el.options[:attr]['href'] =~ /^mailto:/
          el = Marshal.load(Marshal.dump(el)) # so that the original is not changed
          href = obfuscate(el.options[:attr]['href'].sub(/^mailto:/, ''))
          mailto = obfuscate('mailto')
          el.options[:attr]['href'] = "#{mailto}:#{href}"
        end
        res = inner(el, indent, opts)
        res = obfuscate(res) if el.options[:obfuscate_text]
        "<a#{options_for_element(el)}>#{res}</a>"
      end

      def convert_img(el, indent, opts)
        "<img#{options_for_element(el)} />"
      end

      def convert_codespan(el, indent, opts)
        "<code#{options_for_element(el)}>#{escape_html(el.value)}</code>"
      end

      def convert_footnote(el, indent, opts)
        number = @footnote_counter
        @footnote_counter += 1
        @footnotes << [el.options[:name], @doc.parse_infos[:footnotes][el.options[:name]]]
        "<sup id=\"fnref:#{el.options[:name]}\"><a href=\"#fn:#{el.options[:name]}\" rel=\"footnote\">#{number}</a></sup>"
      end

      def convert_raw(el, indent, opts)
        el.value
      end

      def convert_em(el, indent, opts)
        "<#{el.type}#{options_for_element(el)}>#{inner(el, indent, opts)}</#{el.type}>"
      end
      alias :convert_strong :convert_em

      def convert_entity(el, indent, opts)
        "&#{el.value.kind_of?(Integer) ? '#' : ''}#{el.value};"
      end

      TYPOGRAPHIC_SYMS = {
        :mdash => '&mdash;', :ndash => '&ndash;', :ellipsis => '&hellip;',
        :laquo_space => '&laquo;&nbsp;', :raquo_space => '&nbsp;&raquo;',
        :laquo => '&laquo;', :raquo => '&raquo;'
      }
      def convert_typographic_sym(el, indent, opts)
        TYPOGRAPHIC_SYMS[el.value]
      end

      def convert_smart_quote(el, indent, opts)
        "&#{el.value};"
      end

      def convert_root(el, indent, opts)
        inner(el, indent, opts) << footnote_content
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
        (ol.children.empty? ? '' : "<div class=\"footnotes\">\n#{convert(ol, 2)}</div>\n")
      end

      # Return the string with the attributes of the element +el+.
      def options_for_element(el)
        (el.options[:attr] || {}).map {|k,v| v.nil? ? '' : " #{k}=\"#{escape_html(v.to_s, :no_entities)}\"" }.sort.join('')
      end

      ESCAPE_MAP = {
        '<' => '&lt;',
        '>' => '&gt;',
        '&' => '&amp;',
        '"' => '&quot;'
      }
      ESCAPE_ALL_RE = Regexp.union(*ESCAPE_MAP.collect {|k,v| k})
      ESCAPE_NO_ENTITIES_RE = Regexp.union(REXML::Parsers::BaseParser::REFERENCE_RE, ESCAPE_ALL_RE)
      ESCAPE_NORMAL = Regexp.union(REXML::Parsers::BaseParser::REFERENCE_RE, /<|>|&/)
      ESCAPE_RE_FROM_TYPE = {
        :all => ESCAPE_ALL_RE,
        :no_entities => ESCAPE_NO_ENTITIES_RE,
        :text => ESCAPE_NORMAL
      }

      # Escape the special HTML characters in the string +str+. The parameter +type+ specifies what
      # is escaped: <tt>:all</tt> - all special HTML characters as well as entities,
      # <tt>:no_entities</tt> - all special HTML characters but no entities, <tt>:text</tt> - all
      # special HTML characters except the quotation mark but no entities.
      def escape_html(str, type = :all)
        str.gsub(ESCAPE_RE_FROM_TYPE[type]) {|m| ESCAPE_MAP[m] || m}
      end

    end

  end
end
