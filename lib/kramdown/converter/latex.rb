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

module Kramdown

  module Converter

    # Converts a Kramdown::Document to LaTeX. This converter uses ideas from other Markdown-to-LaTeX
    # converters like Pandoc and Maruku.
    class Latex < Base

      # :stopdoc:

      # Initialize the LaTeX converter with the given Kramdown document +doc+.
      def initialize(doc)
        super
        #TODO: set the footnote counter at the beginning of the document
        @doc.options[:footnote_nr]
      end

      def convert(el, opts = {})
        send("convert_#{el.type}", el, opts)
      end

      def inner(el, opts)
        result = ''
        el.children.each do |inner_el|
          result << send("convert_#{inner_el.type}", inner_el, opts)
        end
        result
      end

      def convert_root(el, opts)
        inner(el, opts)
      end

      def convert_blank(el, opts)
        ""
      end

      def convert_text(el, opts)
        escape(el.value)
      end

      def convert_eob(el, opts)
        ''
      end

      def convert_p(el, opts)
        "#{inner(el, opts)}\n\n"
      end

      def convert_codeblock(el, opts)
        show_whitespace = el.options[:attr] && el.options[:attr]['class'].to_s =~ /\bshow-whitespaces\b/
        lang = el.options[:attr] && el.options[:attr]['lang']
        if show_whitespace || lang
          result = "\\lstset{showspaces=%s,showtabs=%s}\n" % (show_whitespace ? ['true', 'true'] : ['false', 'false'])
          result += "\\lstset{language=#{lang}}\n" if lang
          result += "\\lstset{basicstyle=\\ttfamily\\footnotesize}\\lstset{columns=fixed,frame=tlbr}\n"
          "#{result}\\begin{lstlisting}\n#{el.value}\n\\end{lstlisting}"
        else
          "\\begin{verbatim}#{el.value}\\end{verbatim}\n"
        end
      end

      def latex_environment(type, text)
        "\\begin{#{type}}\n#{text}\n\\end{#{type}}\n"
      end

      def convert_blockquote(el, opts)
        latex_environment('quote', inner(el, opts))
      end

      HEADER_TYPES = {
        1 => 'section',
        2 => 'subsection',
        3 => 'subsubsection',
        4 => 'paragraph',
        5 => 'subparagraph',
        6 => 'subparagraph'
      }
      def convert_header(el, opts)
        type = HEADER_TYPES[el.options[:level]]
        if el.options[:attr] && (id = el.options[:attr]['id'])
          "\\hypertarget{#{id}}{}\\#{type}*{#{inner(el, opts)}}\\label{#{id}}\n\n"
        else
          "\\#{type}*{#{inner(el, opts)}}\n\n"
        end
      end

      def convert_hr(el, opts)
        "\\begin{center}\\rule{3in}{0.4pt}\\end{center}\n"
      end

      def convert_ul(el, opts)
        latex_environment('itemize', inner(el, opts))
      end

      def convert_ol(el, opts)
        latex_environment('enumerate', inner(el, opts))
      end

      def convert_dl(el, opts)
        latex_environment('description', inner(el, opts))
      end

      def convert_li(el, opts)
        "\\item #{inner(el, opts)}\n"
      end

      def convert_dt(el, opts)
        "\\item[#{inner(el, opts)}] "
      end

      def convert_dd(el, opts)
        "#{inner(el, opts)}\n\n"
      end

      def convert_html_element(el, opts)
        #TODO: add warning
      end

      def convert_html_text(el, opts)
        #TODO: add warning
      end

      def convert_xml_comment(el, opts)
        ''
      end
      alias :convert_xml_pi :convert_xml_comment

      TABLE_ALIGNMENT_CHAR = {:default => 'l', :left => 'l', :center => 'c', :right => 'r'}

      def convert_table(el, opts)
        align = el.options[:alignment].map {|a| TABLE_ALIGNMENT_CHAR[a]}.join('|')
        "\\begin{tabular}{|#{align}|}\n\\hline\n#{inner(el, opts)}\\hline\n\\end{tabular}\n\n"
      end

      def convert_thead(el, opts)
        "#{inner(el, opts)}\\hline\n"
      end

      def convert_tbody(el, opts)
        inner(el, opts)
      end

      def convert_tfoot(el, opts)
        "\\hline \\hline \n#{inner(el, opts)}"
      end

      def convert_tr(el, opts)
        el.children.map {|c| send("convert_#{c.type}", c, opts)}.join(' & ') + "\\\\\n"
      end

      def convert_td(el, opts)
        inner(el, opts)
      end

      def convert_br(el, opts)
        "\\newline\n"
      end

      def convert_a(el, opts)
        url = el.options[:attr]['href']
        if url =~ /^#/
          "\\hyperlink{#{url[1..-1]}}{#{inner(el, opts)}}"
        else
          "\\href{#{url}}{#{inner(el, opts)}}"
        end
      end

      def convert_img(el, opts)
        #TODO: how to include images? won't work with remote URLs, only local ones, need an option
        #to set the base path or so (e.g. when converting a webgen page file to latex/pdf)
        ""
      end

      def convert_codespan(el, opts)
        "{\\tt #{escape(el.value)}}"
      end

      def convert_footnote(el, opts)
        "\\footnote{#{inner(@doc.parse_infos[:footnotes][el.options[:name]])}}"
      end

      def convert_raw(el, opts)
        #TODO: think about this!!! exclude from output?
        escape(el.value)
      end

      def convert_em(el, opts)
        "\\emph{#{inner(el, opts)}}"
      end

      def convert_strong(el, opts)
        "\\textbf{#{inner(el, opts)}}"
      end

      def convert_entity(el, opts)
        #TODO: need to convert entity to something LaTeX understands..., see text2html conversion
        #table used in maruku el.value
        ''
      end

      TYPOGRAPHIC_SYMS = {
        :mdash => '---', :ndash => '--', :ellipsis => '\ldots{}',
        :laquo_space => '\guillemotleft{}~', :raquo_space => '~\guillemotright{}',
        :laquo => '\guillemotleft{}', :raquo => '\guillemotright{}'
      }
      def convert_typographic_sym(el, opts)
        TYPOGRAPHIC_SYMS[el.value]
      end

      SMART_QUOTE_SYMS = {:lsquo => '`', :rsquo => '\'', :ldquo => '``', :rdquo => '\'\''}
      def convert_smart_quote(el, opts)
        SMART_QUOTE_SYMS[el.value]
      end

      ESCAPE_MAP = {
        "^"  => "\\^{}",
        "\\" => "\\textbackslash{}",
        "~"  => "\\ensuremath{\\sim}",
        "|"  => "\\textbar{}",
        "<"  => "\\textless{}",
        ">"  => "\\textgreater{}"
      }.merge(Hash[*("{}$%&_#".scan(/./).map {|c| [c, "\\#{c}"]}.flatten)])
      ESCAPE_RE = Regexp.union(*ESCAPE_MAP.collect {|k,v| k})

      def escape(str)
        str.gsub(ESCAPE_RE) {|m| ESCAPE_MAP[m]}
      end

    end

  end
end
