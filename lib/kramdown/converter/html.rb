# -*- coding: utf-8 -*-
#
#--
# Copyright (C) 2009-2013 Thomas Leitner <t_leitner@gmx.at>
#
# This file is part of kramdown which is licensed under the MIT.
#++
#

require 'rexml/parsers/baseparser'
require 'kramdown/parser/html'

module Kramdown

  module Converter

    # Converts a Kramdown::Document to HTML.
    #
    # You can customize the HTML converter by sub-classing it and overriding the +convert_NAME+
    # methods. Each such method takes the following parameters:
    #
    # [+el+] The element of type +NAME+ to be converted.
    #
    # [+indent+] A number representing the current amount of spaces for indent (only used for
    #            block-level elements).
    #
    # The return value of such a method has to be a string containing the element +el+ formatted as
    # HTML element.
    class Html < Base

      begin
        require 'coderay'

        # Highlighting via coderay is available if this constant is +true+.
        HIGHLIGHTING_AVAILABLE = true
      rescue LoadError
        HIGHLIGHTING_AVAILABLE = false  # :nodoc:
      end

      include ::Kramdown::Utils::Html
      include ::Kramdown::Parser::Html::Constants

      # The amount of indentation used when nesting HTML tags.
      attr_accessor :indent

      # Initialize the HTML converter with the given Kramdown document +doc+.
      def initialize(root, options)
        super
        @footnote_counter = @footnote_start = @options[:footnote_nr]
        @footnotes = []
        @footnotes_by_name = {}
        @toc = []
        @toc_code = nil
        @indent = 2
        @stack = []
        @coderay_enabled = @options[:enable_coderay] && HIGHLIGHTING_AVAILABLE
      end

      # The mapping of element type to conversion method.
      DISPATCHER = Hash.new {|h,k| h[k] = "convert_#{k}"}

      # Dispatch the conversion of the element +el+ to a +convert_TYPE+ method using the +type+ of
      # the element.
      def convert(el, indent = -@indent)
        send(DISPATCHER[el.type], el, indent)
      end

      # Return the converted content of the children of +el+ as a string. The parameter +indent+ has
      # to be the amount of indentation used for the element +el+.
      #
      # Pushes +el+ onto the @stack before converting the child elements and pops it from the stack
      # afterwards.
      def inner(el, indent)
        result = ''
        indent += @indent
        @stack.push(el)
        el.children.each do |inner_el|
          result << send(DISPATCHER[inner_el.type], inner_el, indent)
        end
        @stack.pop
        result
      end

      def convert_blank(el, indent)
        "\n"
      end

      def convert_text(el, indent)
        escape_html(el.value, :text)
      end

      def convert_p(el, indent)
        if el.options[:transparent]
          inner(el, indent)
        else
          format_as_block_html(el.type, el.attr, inner(el, indent), indent)
        end
      end

      def convert_codeblock(el, indent)
        attr = el.attr.dup
        lang = extract_code_language!(attr)
        if @coderay_enabled && (lang || @options[:coderay_default_lang])
          opts = {:wrap => @options[:coderay_wrap], :line_numbers => @options[:coderay_line_numbers],
            :line_number_start => @options[:coderay_line_number_start], :tab_width => @options[:coderay_tab_width],
            :bold_every => @options[:coderay_bold_every], :css => @options[:coderay_css]}
          lang = (lang || @options[:coderay_default_lang]).to_sym
          result = CodeRay.scan(el.value, lang).html(opts).chomp << "\n"
          "#{' '*indent}<div#{html_attributes(attr)}>#{result}#{' '*indent}</div>\n"
        else
          result = escape_html(el.value)
          result.chomp!
          if el.attr['class'].to_s =~ /\bshow-whitespaces\b/
            result.gsub!(/(?:(^[ \t]+)|([ \t]+$)|([ \t]+))/) do |m|
              suffix = ($1 ? '-l' : ($2 ? '-r' : ''))
              m.scan(/./).map do |c|
                case c
                when "\t" then "<span class=\"ws-tab#{suffix}\">\t</span>"
                when " " then "<span class=\"ws-space#{suffix}\">&#8901;</span>"
                end
              end.join('')
            end
          end
          code_attr = {}
          code_attr['class'] = "language-#{lang}" if lang
          "#{' '*indent}<pre#{html_attributes(attr)}><code#{html_attributes(code_attr)}>#{result}\n</code></pre>\n"
        end
      end

      def convert_blockquote(el, indent)
        format_as_indented_block_html(el.type, el.attr, inner(el, indent), indent)
      end

      def convert_header(el, indent)
        attr = el.attr.dup
        if @options[:auto_ids] && !attr['id']
          attr['id'] = generate_id(el.options[:raw_text])
        end
        @toc << [el.options[:level], attr['id'], el.children] if attr['id'] && in_toc?(el)
        level = output_header_level(el.options[:level])
        format_as_block_html("h#{level}", attr, inner(el, indent), indent)
      end

      def convert_hr(el, indent)
        "#{' '*indent}<hr />\n"
      end

      def convert_ul(el, indent)
        if !@toc_code && (el.options[:ial][:refs].include?('toc') rescue nil) && (el.type == :ul || el.type == :ol)
          @toc_code = [el.type, el.attr, (0..128).to_a.map{|a| rand(36).to_s(36)}.join]
          @toc_code.last
        else
          format_as_indented_block_html(el.type, el.attr, inner(el, indent), indent)
        end
      end
      alias :convert_ol :convert_ul
      alias :convert_dl :convert_ul

      def convert_li(el, indent)
        output = ' '*indent << "<#{el.type}" << html_attributes(el.attr) << ">"
        res = inner(el, indent)
        if el.children.empty? || (el.children.first.type == :p && el.children.first.options[:transparent])
          output << res << (res =~ /\n\Z/ ? ' '*indent : '')
        else
          output << "\n" << res << ' '*indent
        end
        output << "</#{el.type}>\n"
      end
      alias :convert_dd :convert_li

      def convert_dt(el, indent)
        format_as_block_html(el.type, el.attr, inner(el, indent), indent)
      end

      def convert_html_element(el, indent)
        res = inner(el, indent)
        if el.options[:category] == :span
          "<#{el.value}#{html_attributes(el.attr)}" << (res.empty? && HTML_ELEMENTS_WITHOUT_BODY.include?(el.value) ? " />" : ">#{res}</#{el.value}>")
        else
          output = ''
          output << ' '*indent if @stack.last.type != :html_element || @stack.last.options[:content_model] != :raw
          output << "<#{el.value}#{html_attributes(el.attr)}"
          if el.options[:is_closed] && el.options[:content_model] == :raw
            output << " />"
          elsif !res.empty? && el.options[:content_model] != :block
            output << ">#{res}</#{el.value}>"
          elsif !res.empty?
            output << ">\n#{res.chomp}\n"  << ' '*indent << "</#{el.value}>"
          elsif HTML_ELEMENTS_WITHOUT_BODY.include?(el.value)
            output << " />"
          else
            output << "></#{el.value}>"
          end
          output << "\n" if @stack.last.type != :html_element || @stack.last.options[:content_model] != :raw
          output
        end
      end

      def convert_xml_comment(el, indent)
        if el.options[:category] == :block && (@stack.last.type != :html_element || @stack.last.options[:content_model] != :raw)
          ' '*indent << el.value << "\n"
        else
          el.value
        end
      end
      alias :convert_xml_pi :convert_xml_comment

      def convert_table(el, indent)
        format_as_indented_block_html(el.type, el.attr, inner(el, indent), indent)
      end
      alias :convert_thead :convert_table
      alias :convert_tbody :convert_table
      alias :convert_tfoot :convert_table
      alias :convert_tr  :convert_table

      ENTITY_NBSP = ::Kramdown::Utils::Entities.entity('nbsp') # :nodoc:

      def convert_td(el, indent)
        res = inner(el, indent)
        type = (@stack[-2].type == :thead ? :th : :td)
        attr = el.attr
        alignment = @stack[-3].options[:alignment][@stack.last.children.index(el)]
        if alignment != :default
          attr = el.attr.dup
          attr['style'] = (attr.has_key?('style') ? "#{attr['style']}; ": '') << "text-align: #{alignment}"
        end
        format_as_block_html(type, attr, res.empty? ? entity_to_str(ENTITY_NBSP) : res, indent)
      end

      def convert_comment(el, indent)
        if el.options[:category] == :block
          "#{' '*indent}<!-- #{el.value} -->\n"
        else
          "<!-- #{el.value} -->"
        end
      end

      def convert_br(el, indent)
        "<br />"
      end

      def convert_a(el, indent)
        res = inner(el, indent)
        attr = el.attr.dup
        if attr['href'] =~ /^mailto:/
          mail_addr = attr['href'].sub(/^mailto:/, '')
          attr['href'] = obfuscate('mailto') << ":" << obfuscate(mail_addr)
          res = obfuscate(res) if res == mail_addr
        end
        format_as_span_html(el.type, attr, res)
      end

      def convert_img(el, indent)
        "<img#{html_attributes(el.attr)} />"
      end

      def convert_codespan(el, indent)
        lang = extract_code_language(el.attr)
        result = if @coderay_enabled && lang
                   CodeRay.scan(el.value, lang.to_sym).html(:wrap => :span, :css => @options[:coderay_css]).chomp
                 else
                   escape_html(el.value)
                 end
        format_as_span_html('code', el.attr, result)
      end

      def convert_footnote(el, indent)
        if @footnotes_by_name[el.options[:name]]
          number = @footnotes_by_name[el.options[:name]][2]
        else
          number = @footnote_counter
          @footnote_counter += 1
          @footnotes << [el.options[:name], el.value, number]
          @footnotes_by_name[el.options[:name]] = @footnotes.last
        end
        "<sup id=\"fnref:#{el.options[:name]}\"><a href=\"#fn:#{el.options[:name]}\" class=\"footnote\">#{number}</a></sup>"
      end

      def convert_raw(el, indent)
        if !el.options[:type] || el.options[:type].empty? || el.options[:type].include?('html')
          el.value + (el.options[:category] == :block ? "\n" : '')
        else
          ''
        end
      end

      def convert_em(el, indent)
        format_as_span_html(el.type, el.attr, inner(el, indent))
      end
      alias :convert_strong :convert_em

      def convert_entity(el, indent)
        entity_to_str(el.value, el.options[:original])
      end

      TYPOGRAPHIC_SYMS = {
        :mdash => [::Kramdown::Utils::Entities.entity('mdash')],
        :ndash => [::Kramdown::Utils::Entities.entity('ndash')],
        :hellip => [::Kramdown::Utils::Entities.entity('hellip')],
        :laquo_space => [::Kramdown::Utils::Entities.entity('laquo'), ::Kramdown::Utils::Entities.entity('nbsp')],
        :raquo_space => [::Kramdown::Utils::Entities.entity('nbsp'), ::Kramdown::Utils::Entities.entity('raquo')],
        :laquo => [::Kramdown::Utils::Entities.entity('laquo')],
        :raquo => [::Kramdown::Utils::Entities.entity('raquo')]
      } # :nodoc:
      def convert_typographic_sym(el, indent)
        TYPOGRAPHIC_SYMS[el.value].map {|e| entity_to_str(e)}.join('')
      end

      def convert_smart_quote(el, indent)
        entity_to_str(smart_quote_entity(el))
      end

      def convert_math(el, indent)
        block = (el.options[:category] == :block)
        value = (el.value =~ /<|&/ ? "% <![CDATA[\n#{el.value} %]]>" : el.value)
        type = {:type => "math/tex#{block ? '; mode=display' : ''}"}
        if block
          format_as_block_html('script', type, value, indent)
        else
          format_as_span_html('script', type, value)
        end
      end

      def convert_abbreviation(el, indent)
        title = @root.options[:abbrev_defs][el.value]
        format_as_span_html("abbr", {:title => (title.empty? ? nil : title)}, el.value)
      end

      def convert_root(el, indent)
        result = inner(el, indent)
        result << footnote_content
        if @toc_code
          toc_tree = generate_toc_tree(@toc, @toc_code[0], @toc_code[1] || {})
          text = if toc_tree.children.size > 0
                   convert(toc_tree, 0)
                 else
                   ''
                 end
          result.sub!(/#{@toc_code.last}/, text)
        end
        result
      end

      # Format the given element as span HTML.
      def format_as_span_html(name, attr, body)
        "<#{name}#{html_attributes(attr)}>#{body}</#{name}>"
      end

      # Format the given element as block HTML.
      def format_as_block_html(name, attr, body, indent)
        "#{' '*indent}<#{name}#{html_attributes(attr)}>#{body}</#{name}>\n"
      end

      # Format the given element as block HTML with a newline after the start tag and indentation
      # before the end tag.
      def format_as_indented_block_html(name, attr, body, indent)
        "#{' '*indent}<#{name}#{html_attributes(attr)}>\n#{body}#{' '*indent}</#{name}>\n"
      end

      # Generate and return an element tree for the table of contents.
      def generate_toc_tree(toc, type, attr)
        sections = Element.new(type, nil, attr)
        sections.attr['id'] ||= 'markdown-toc'
        stack = []
        toc.each do |level, id, children|
          li = Element.new(:li, nil, nil, {:level => level})
          li.children << Element.new(:p, nil, nil, {:transparent => true})
          a = Element.new(:a, nil, {'href' => "##{id}"})
          a.children.concat(remove_footnotes(Marshal.load(Marshal.dump(children))))
          li.children.last.children << a
          li.children << Element.new(type)

          success = false
          while !success
            if stack.empty?
              sections.children << li
              stack << li
              success = true
            elsif stack.last.options[:level] < li.options[:level]
              stack.last.children.last.children << li
              stack << li
              success = true
            else
              item = stack.pop
              item.children.pop unless item.children.last.children.size > 0
            end
          end
        end
        while !stack.empty?
          item = stack.pop
          item.children.pop unless item.children.last.children.size > 0
        end
        sections
      end

      # Remove all footnotes from the given elements.
      def remove_footnotes(elements)
        elements.delete_if do |c|
          remove_footnotes(c.children)
          c.type == :footnote
        end
      end

      # Obfuscate the +text+ by using HTML entities.
      def obfuscate(text)
        result = ""
        text.each_byte do |b|
          result << (b > 128 ? b.chr : "&#%03d;" % b)
        end
        result.force_encoding(text.encoding) if result.respond_to?(:force_encoding)
        result
      end

      # Return a HTML ordered list with the footnote content for the used footnotes.
      def footnote_content
        ol = Element.new(:ol)
        ol.attr['start'] = @footnote_start if @footnote_start != 1
        @footnotes.each do |name, data, number|
          li = Element.new(:li, nil, {'id' => "fn:#{name}"})
          li.children = Marshal.load(Marshal.dump(data.children))
          ol.children << li

          ref = Element.new(:raw, "<a href=\"#fnref:#{name}\" class=\"reversefootnote\">&#8617;</a>")
          if li.children.last.type == :p
            para = li.children.last
          else
            li.children << (para = Element.new(:p))
          end
          para.children << ref
        end
        (ol.children.empty? ? '' : format_as_indented_block_html('div', {:class => "footnotes"}, convert(ol, 2), 0))
      end

    end

  end
end
