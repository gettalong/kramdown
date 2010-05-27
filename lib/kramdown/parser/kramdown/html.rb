# -*- coding: utf-8 -*-
#
#--
# Copyright (C) 2009-2010 Thomas Leitner <t_leitner@gmx.at>
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
  module Parser
    class Kramdown

      #:stopdoc:
      # The following regexps are based on the ones used by REXML, with some slight modifications.
      #:startdoc:
      HTML_COMMENT_RE = /<!--(.*?)-->/m
      HTML_INSTRUCTION_RE = /<\?(.*?)\?>/m
      HTML_ATTRIBUTE_RE = /\s*(#{REXML::Parsers::BaseParser::UNAME_STR})\s*=\s*(["'])(.*?)\2/m
      HTML_TAG_RE = /<((?>#{REXML::Parsers::BaseParser::UNAME_STR}))\s*((?>\s+#{REXML::Parsers::BaseParser::UNAME_STR}\s*=\s*(["']).*?\3)*)\s*(\/)?>/m
      HTML_TAG_CLOSE_RE = /<\/(#{REXML::Parsers::BaseParser::NAME_STR})\s*>/m


      HTML_PARSE_AS_BLOCK = %w{applet button blockquote colgroup dd div dl fieldset form iframe li
                               map noscript object ol table tbody td th thead tfoot tr ul}
      HTML_PARSE_AS_SPAN  = %w{a abbr acronym address b bdo big cite caption del dfn dt em
                               h1 h2 h3 h4 h5 h6 i ins kbd label legend optgroup p q rb rbc
                               rp rt rtc ruby samp select small span strong sub sup tt var}
      HTML_PARSE_AS_RAW   = %w{script math option textarea pre code}

      HTML_PARSE_AS = Hash.new {|h,k| h[k] = :raw}
      HTML_PARSE_AS_BLOCK.each {|i| HTML_PARSE_AS[i] = :block}
      HTML_PARSE_AS_SPAN.each {|i| HTML_PARSE_AS[i] = :span}
      HTML_PARSE_AS_RAW.each {|i| HTML_PARSE_AS[i] = :raw}


      HTML_TO_NATIVE_RAW_TEXT_PROC = lambda do |c, raw|
        raw << c.value.to_s if [:raw_text, :text, :codespan, :codeblock].include?(c.type)
        c.children.each {|cc| HTML_TO_NATIVE_RAW_TEXT_PROC.call(cc, raw)}
      end
      HTML_TO_NATIVE_BASIC_EL = %w{em strong blockquote hr br a img dt p thead tbody tfoot tr td th}
      HTML_TO_NATIVE_BASIC_PROC = lambda do |el|
        el.type = el.value.intern;
        el.options[:category] = HTML_SPAN_ELEMENTS.include?(el.value) ? :span : :block
        el.value = nil
      end
      HTML_TO_NATIVE_HEADER_EL = %w{h1 h2 h3 h4 h5 h6}
      HTML_TO_NATIVE_HEADER_PROC = lambda do |el|
        el.type = :header
        el.options[:level] = el.value[1..1].to_i
        el.options[:category] = :block
        el.value = nil
        HTML_TO_NATIVE_RAW_TEXT_PROC.call(el, el.options[:raw_text] = '')
      end
      HTML_TO_NATIVE_CODE_EL = %w{code pre}
      HTML_TO_NATIVE_CODE_PROC = lambda do |el, *second|
        if second.empty?
          el.type, el.options[:category] = if el.value == 'code'
                                             [:codespan, :span]
                                           else
                                             [:codeblock, :block]
                                           end
          el.value = nil
          raw = Element.new(:raw_text, '')
          HTML_TO_NATIVE_RAW_TEXT_PROC.call(el, raw.value)
          el.children.clear
          el.children << raw
        elsif el.children.size == 1
          el.value = el.children.first.value
          el.children.clear
        end
      end
      HTML_TO_NATIVE_LIST_EL = %w{ul ol dl}
      HTML_TO_NATIVE_LIST_PROC = lambda do |el|
        el.type = el.value.intern
        el.options[:category] = :block
        el.value = nil
        helper = lambda do |c|
          if c.type != :li && c.type != :dt && c.type != :dd
            c.children.delete_if {|cc| cc.type == :raw_text || cc.type == :text}
            c.children.each {|cc| helper.call(cc)}
          end
        end
        helper.call(el)
      end
      HTML_TO_NATIVE_LIST_CONT_EL = %w{li dd}
      HTML_TO_NATIVE_LIST_CONT_PROC = lambda do |el|
        el.type = el.value.intern
        el.options[:category] = :block
        el.value = nil
        i = 0
        while i < el.children.length
          c = el.children[i]
          if (c.type == :raw_text || c.type == :text) && c.value.strip.empty? &&
              (i == 0 || i == el.children.length - 1 || el.children[i-1].options[:category] == :block ||
               el.children[i+1].options[:category] == :block)
            el.children.delete_at(i)
          else
            i += 1
          end
        end
      end
      HTML_TO_NATIVE = {
        'table' => lambda do |el|
          el.type = :table
          el.options[:category] = :block
          el.value = nil
          el.options[:alignment] = []
          helper = lambda do |c|
            if c.type != :td && c.type != :th
              c.children.delete_if {|cc| cc.type == :raw_text || cc.type == :text}
              c.children.each {|cc| helper.call(cc)}
            end
            if c.type == :tr && el.options[:alignment].empty?
              el.options[:alignment] = [:default] * c.children.inject(0) do |sum, cc|
                cc.type == :th || cc.type == :td ? sum + 1 : sum
              end
            end
          end
          helper.call(el)
        end,
      }
      HTML_TO_NATIVE_BASIC_EL.each {|i| HTML_TO_NATIVE[i] = HTML_TO_NATIVE_BASIC_PROC}
      HTML_TO_NATIVE_HEADER_EL.each {|i| HTML_TO_NATIVE[i] = HTML_TO_NATIVE_HEADER_PROC}
      HTML_TO_NATIVE_CODE_EL.each {|i| HTML_TO_NATIVE[i] = HTML_TO_NATIVE_CODE_PROC}
      HTML_TO_NATIVE_LIST_EL.each {|i| HTML_TO_NATIVE[i] = HTML_TO_NATIVE_LIST_PROC}
      HTML_TO_NATIVE_LIST_CONT_EL.each {|i| HTML_TO_NATIVE[i] = HTML_TO_NATIVE_LIST_CONT_PROC}

      #:stopdoc:
      # Some HTML elements like script belong to both categories (i.e. are valid in block and
      # span HTML) and don't appear therefore!
      #:startdoc:
      HTML_SPAN_ELEMENTS = %w{a abbr acronym b big bdo br button cite code del dfn em i img input
                              ins kbd label option q rb rbc rp rt rtc ruby samp select small span
                              strong sub sup textarea tt var}
      HTML_BLOCK_ELEMENTS = %w{address applet button blockquote caption col colgroup dd div dl dt fieldset
                               form h1 h2 h3 h4 h5 h6 hr iframe legend li map ol optgroup p pre table tbody
                               td th thead tfoot tr ul}
      HTML_ELEMENTS_WITHOUT_BODY = %w{area br col hr img input}

      HTML_BLOCK_START = /^#{OPT_SPACE}<(#{REXML::Parsers::BaseParser::UNAME_STR}|\?|!--|\/)/
      HTML_RAW_START = /(?=<(#{REXML::Parsers::BaseParser::UNAME_STR}|\/))/

      # Parse the HTML at the current position as block level HTML.
      def parse_block_html
        if result = @src.scan(HTML_COMMENT_RE)
          @tree.children << Element.new(:xml_comment, result, :category => :block)
          @src.scan(/[ \t]*\n/)
          true
        elsif result = @src.scan(HTML_INSTRUCTION_RE)
          @tree.children << Element.new(:xml_pi, result, :category => :block)
          @src.scan(/[ \t]*\n/)
          true
        else
          if result = @src.check(/^#{OPT_SPACE}#{HTML_TAG_RE}/) && !HTML_SPAN_ELEMENTS.include?(@src[1])
            @src.pos += @src.matched_size
            handle_html_start_tag
            true
          elsif result = @src.check(/^#{OPT_SPACE}#{HTML_TAG_CLOSE_RE}/) && !HTML_SPAN_ELEMENTS.include?(@src[1])
            @src.pos += @src.matched_size
            name = @src[1]

            if @tree.type == :html_element && @tree.value == name
              throw :stop_block_parsing, :found
            else
              warning("Found invalidly used HTML closing tag for '#{name}' - ignoring it")
              true
            end
          else
            false
          end
        end
      end
      define_parser(:block_html, HTML_BLOCK_START)


      # Return the HTML parse type defined by the string +val+, i.e. raw when "0", default parsing
      # (return value +nil+) when "1", span parsing when "span" and block parsing when "block". If
      # +val+ is nil, then the default parsing mode is used.
      def get_parse_type(val)
        case val
        when "0" then :raw
        when "1" then :default
        when "span" then :span
        when "block" then :block
        when NilClass then nil
        else
          warning("Invalid markdown attribute val '#{val}', using default")
          nil
        end
      end

      # Process the HTML start tag that has already be scanned/checked.
      def handle_html_start_tag
        curpos = @src.pos
        name = @src[1]
        closed = !@src[4].nil?
        attrs = {}
        @src[2].scan(HTML_ATTRIBUTE_RE).each {|attr,sep,val| attrs[attr] = val}

        parse_type = if @tree.type != :html_element || @tree.options[:parse_type] != :raw
                       (@doc.options[:parse_block_html] ? HTML_PARSE_AS[name] : :raw)
                     else
                       :raw
                     end
        if val = get_parse_type(attrs.delete('markdown'))
          parse_type = (val == :default ? HTML_PARSE_AS[name] : val)
        end

        @src.scan(/[ \t]*\n/) if parse_type == :block

        el = Element.new(:html_element, name, :attr => attrs, :category => :block, :parse_type => parse_type)
        el.options[:outer_element] = true if @tree.type != :html_element
        el.options[:parent_is_raw] = true if @tree.type == :html_element && @tree.options[:parse_type] == :raw
        @tree.children << el

        if !closed && HTML_ELEMENTS_WITHOUT_BODY.include?(el.value)
          warning("The HTML tag '#{el.value}' cannot have any content - auto-closing it")
        elsif !closed
          if parse_type == :block
            end_tag_found = parse_blocks(el)
            if !end_tag_found
              warning("Found no end tag for '#{el.value}' - auto-closing it")
            end
          elsif parse_type == :span
            if result = @src.scan_until(/(?=<\/#{el.value}\s*>)/m)
              add_text(extract_string(curpos...@src.pos), el)
              @src.scan(HTML_TAG_CLOSE_RE)
            else
              add_text(@src.scan(/.*/m), el)
              warning("Found no end tag for '#{el.value}' - auto-closing it")
            end
          else
            parse_raw_html(el)
          end
          @src.scan(/[ \t]*\n/) unless (@tree.type == :html_element && @tree.options[:parse_type] == :raw)
        end
        post_process_html_element(el)
      end

      # Converts the HTML element +el+ to a native element if possible.
      def post_process_html_element(el)
        if @doc.options[:html_to_native] && (processor = HTML_TO_NATIVE[el.value])
          processor.call(el)
          post_process_html_text(el)
          processor.call(el, :after) if processor.arity < 0
        end
      end

      # Post process the HTML text.
      def post_process_html_text(el)
        el.children.map! do |child|
          if child.type == :raw_text
            oldsrc, @src = @src, StringScanner.new(child.value)
            parse_spans(child, nil, [:html_entity], :raw_text)
            @src = oldsrc
            child.children.each do |c|
              if c.type == :entity
                if %w{lsquo rsquo ldquo rdquo}.include?(c.value)
                  c.type = :smart_quote
                  c.value = c.value.intern
                elsif %w{mdash ndash hellip laquo raquo}.include?(c.value)
                  c.type = :typographic_sym
                  c.value = c.value.intern
                end
              end
            end
          else
            post_process_html_text(child)
            child
          end
        end.flatten!
      end

      # Parse raw HTML until the matching end tag for +el+ is found or until the end of the
      # document.
      def parse_raw_html(el)
        @stack.push(@tree)
        @tree = el

        done = false
        endpos = nil
        while !@src.eos? && !done
          if result = @src.scan_until(HTML_RAW_START)
            endpos = @src.pos
            add_text(result, @tree, :raw_text)
            if @src.scan(HTML_TAG_RE)
              handle_html_start_tag
            elsif @src.scan(HTML_TAG_CLOSE_RE)
              if @tree.value == @src[1]
                done = true
              else
                warning("Found invalidly used HTML closing tag for '#{@src[1]}' - ignoring it")
              end
            else
              add_text(@src.scan(/./), @tree, :raw_text)
            end
          else
            result = @src.scan(/.*/m)
            add_text(result, @tree, :raw_text)
            warning("Found no end tag for '#{@tree.value}' - auto-closing it")
            done = true
          end
        end

        @tree = @stack.pop
        endpos
      end


      HTML_SPAN_START = /<(#{REXML::Parsers::BaseParser::UNAME_STR}|\?|!--|\/)/

      # Parse the HTML at the current position as span level HTML.
      def parse_span_html
        if result = @src.scan(HTML_COMMENT_RE)
          @tree.children << Element.new(:xml_comment, result, :category => :span)
        elsif result = @src.scan(HTML_INSTRUCTION_RE)
          @tree.children << Element.new(:xml_pi, result, :category => :span)
        elsif result = @src.scan(HTML_TAG_CLOSE_RE)
          warning("Found invalidly used HTML closing tag for '#{@src[1]}' - ignoring it")
        elsif result = @src.scan(HTML_TAG_RE)
          return if HTML_BLOCK_ELEMENTS.include?(@src[1])

          reset_pos = @src.pos
          attrs = {}
          @src[2].scan(HTML_ATTRIBUTE_RE).each {|name,sep,val| attrs[name] = val.gsub(/\n+/, ' ')}

          do_parsing = (HTML_PARSE_AS_RAW.include?(@src[1]) || @tree.options[:parse_type] == :raw ? false : @doc.options[:parse_span_html])
          if val = get_parse_type(attrs.delete('markdown'))
            if val == :block
              warning("Cannot use block level parsing in span level HTML tag - using default mode")
            elsif val == :span
              do_parsing = true
            elsif val == :default
              do_parsing = !HTML_PARSE_AS_RAW.include?(@src[1])
            elsif val == :raw
              do_parsing = false
            end
          end

          el = Element.new(:html_element, @src[1], :attr => attrs, :category => :span, :parse_type => (do_parsing ? :span : :raw))
          stop_re = /<\/#{Regexp.escape(@src[1])}\s*>/
          if @src[4]
            @tree.children << el
          elsif HTML_ELEMENTS_WITHOUT_BODY.include?(el.value)
            warning("The HTML tag '#{el.value}' cannot have any content - auto-closing it")
            @tree.children << el
          else
            if parse_spans(el, stop_re, (do_parsing ? nil : [:span_html]), (do_parsing ? :text : :raw_text))
              @src.scan(stop_re)
            else
              warning("Found no end tag for '#{el.value}' - auto-closing it")
              add_text(@src.scan(/.*/m), el, (do_parsing ? :text : :raw_text))
            end
            @tree.children << el
          end
          post_process_html_element(el)
        else
          add_text(@src.scan(/./))
        end
      end
      define_parser(:span_html, HTML_SPAN_START, '<')

    end
  end
end
