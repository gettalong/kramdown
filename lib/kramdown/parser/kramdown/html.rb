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
  module Parser
    class Kramdown

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

      # Special version of #add_text which either creates a :text element or a :raw element,
      # depending on the HTML element type.
      def add_html_text(text, tree)
        type = (tree.options[:parse_type] == :raw ? :raw : :text)
        if tree.children.last && tree.children.last.type == type
          tree.children.last.value << text
        elsif !text.empty?
          tree.children << Element.new(type, text)
        end
      end

      #:stopdoc:
      # The following regexps are based on the ones used by REXML, with some slight modifications.
      #:startdoc:
      HTML_COMMENT_RE = /<!--(.*?)-->/m
      HTML_INSTRUCTION_RE = /<\?(.*?)\?>/m
      HTML_ATTRIBUTE_RE = /\s*(#{REXML::Parsers::BaseParser::UNAME_STR})\s*=\s*(["'])(.*?)\2/m
      HTML_TAG_RE = /<((?>#{REXML::Parsers::BaseParser::UNAME_STR}))\s*((?>\s+#{REXML::Parsers::BaseParser::UNAME_STR}\s*=\s*(["']).*?\3)*)\s*(\/)?>/m
      HTML_TAG_CLOSE_RE = /<\/(#{REXML::Parsers::BaseParser::NAME_STR})\s*>/


      HTML_PARSE_AS_BLOCK = %w{applet button blockquote colgroup dd div dl fieldset form iframe li
                               map noscript object ol table tbody td th thead tfoot tr ul}
      HTML_PARSE_AS_SPAN  = %w{a abbr acronym address b bdo big cite caption code del dfn dt em
                               h1 h2 h3 h4 h5 h6 i ins kbd label legend optgroup p pre q rb rbc
                               rp rt rtc ruby samp select small span strong sub sup tt var}
      HTML_PARSE_AS_RAW   = %w{script math option textarea}

      HTML_PARSE_AS = Hash.new {|h,k| h[k] = :raw}
      HTML_PARSE_AS_BLOCK.each {|i| HTML_PARSE_AS[i] = :block}
      HTML_PARSE_AS_SPAN.each {|i| HTML_PARSE_AS[i] = :span}
      HTML_PARSE_AS_RAW.each {|i| HTML_PARSE_AS[i] = :raw}

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

      # Parse the HTML at the current position as block level HTML.
      def parse_block_html
        if result = @src.scan(HTML_COMMENT_RE)
          @tree.children << Element.new(:html_raw, result, :type => :block)
          @src.scan(/.*?\n/)
          true
        elsif result = @src.scan(HTML_INSTRUCTION_RE)
          @tree.children << Element.new(:html_raw, result, :type => :block)
          @src.scan(/.*?\n/)
          true
        else
          if (!@src.check(/^#{OPT_SPACE}#{HTML_TAG_RE}/) && !@src.check(/^#{OPT_SPACE}#{HTML_TAG_CLOSE_RE}/)) ||
              HTML_SPAN_ELEMENTS.include?(@src[1])
            if @tree.type == :html_element && @tree.options[:parse_type] != :block
              add_html_text(@src.scan(/.*?\n/), @tree)
              add_html_text(@src.scan_until(/(?=#{HTML_BLOCK_START})|\Z/), @tree)
              return true
            else
              return false
            end
          end

          current_el = (@tree.type == :html_element ? @tree : nil)
          @src.scan(/^(#{OPT_SPACE})(.*?)\n/)
          if current_el && current_el.options[:parse_type] == :raw
            add_html_text(@src[1], current_el)
          end
          line = @src[2]
          stack = []

          while line.size > 0
            index_start_tag, index_close_tag = line.index(HTML_TAG_RE), line.index(HTML_TAG_CLOSE_RE)
            if index_start_tag && (!index_close_tag || index_start_tag < index_close_tag)
              md = line.match(HTML_TAG_RE)
              line = md.post_match
              add_html_text(md.pre_match, current_el) if current_el
              if HTML_SPAN_ELEMENTS.include?(md[1]) || (current_el && current_el.options[:parse_type] == :span)
                add_html_text(md.to_s, current_el) if current_el
                next
              end

              attrs = {}
              md[2].scan(HTML_ATTRIBUTE_RE).each {|name,sep,val| attrs[name] = val}

              parse_type = if !current_el || current_el.options[:parse_type] != :raw
                             (@doc.options[:parse_block_html] ? HTML_PARSE_AS[md[1]] : :raw)
                           else
                             :raw
                           end
              if val = get_parse_type(attrs.delete('markdown'))
                parse_type = (val == :default ? HTML_PARSE_AS[md[1]] : val)
              end
              el = Element.new(:html_element, md[1], :attr => attrs, :type => :block, :parse_type => parse_type)
              el.options[:no_start_indent] = true if !stack.empty?
              el.options[:outer_element] = true if !current_el
              el.options[:parent_is_raw] = true if current_el && current_el.options[:parse_type] == :raw

              @tree.children << el
              if !md[4] && HTML_ELEMENTS_WITHOUT_BODY.include?(el.value)
                warning("The HTML tag '#{el.value}' cannot have any content - auto-closing it")
              elsif !md[4]
                @unclosed_html_tags.push(el)
                @stack.push(@tree)
                stack.push(current_el)
                @tree = current_el = el
              end
            elsif index_close_tag
              md = line.match(HTML_TAG_CLOSE_RE)
              line = md.post_match
              add_html_text(md.pre_match, current_el) if current_el

              if @unclosed_html_tags.size > 0 && md[1] == @unclosed_html_tags.last.value
                el = @unclosed_html_tags.pop
                @tree = @stack.pop
                current_el.options[:compact] = true if stack.size > 0
                current_el = stack.pop || (@tree.type == :html_element ? @tree : nil)
              else
                if !HTML_SPAN_ELEMENTS.include?(md[1]) && @tree.options[:parse_type] != :span
                  warning("Found invalidly used HTML closing tag for '#{md[1]}'")
                elsif current_el
                  add_html_text(md.to_s, current_el)
                end
              end
            else
              if current_el
                line.rstrip! if current_el.options[:parse_type] == :block
                add_html_text(line + "\n", current_el)
              else
                add_text(line + "\n")
              end
              line = ''
            end
          end
          if current_el && (current_el.options[:parse_type] == :span || current_el.options[:parse_type] == :raw)
            result = @src.scan_until(/(?=#{HTML_BLOCK_START})|\Z/)
            last = current_el.children.last
            result = "\n" + result if last.nil? || (last.type != :text && last.type != :raw) || last.value !~ /\n\Z/
            add_html_text(result, current_el)
          end
          true
        end
      end
      define_parser(:block_html, HTML_BLOCK_START)


      HTML_SPAN_START = /<(#{REXML::Parsers::BaseParser::UNAME_STR}|\?|!--)/

      # Parse the HTML at the current position as span level HTML.
      def parse_span_html
        if result = @src.scan(HTML_COMMENT_RE)
          @tree.children << Element.new(:html_raw, result, :type => :span)
        elsif result = @src.scan(HTML_INSTRUCTION_RE)
          @tree.children << Element.new(:html_raw, result, :type => :span)
        elsif result = @src.scan(HTML_TAG_RE)
          if HTML_BLOCK_ELEMENTS.include?(@src[1])
            add_text(result)
            return
          end
          reset_pos = @src.pos
          attrs = {}
          @src[2].scan(HTML_ATTRIBUTE_RE).each {|name,sep,val| attrs[name] = val.gsub(/\n+/, ' ')}

          do_parsing = @doc.options[:parse_span_html]
          if val = get_parse_type(attrs.delete('markdown'))
            if val == :block
              warning("Cannot use block level parsing in span level HTML tag - using default mode")
            elsif val == :span || val == :default
              do_parsing = true
            elsif val == :raw
              do_parsing = false
            end
          end
          do_parsing = false if HTML_PARSE_AS_RAW.include?(@src[1])

          el = Element.new(:html_element, @src[1], :attr => attrs, :type => :span)
          stop_re = /<\/#{Regexp.escape(@src[1])}\s*>/
          if @src[4]
            @tree.children << el
          elsif HTML_ELEMENTS_WITHOUT_BODY.include?(el.value)
            warning("The HTML tag '#{el.value}' cannot have any content - auto-closing it")
            @tree.children << el
          else
            if parse_spans(el, stop_re)
              end_pos = @src.pos
              @src.scan(stop_re)
              @tree.children << el
              if !do_parsing
                el.children.clear
                el.children << Element.new(:raw, @src.string[reset_pos...end_pos])
              end
            else
              @src.pos = reset_pos
              add_text(result)
            end
          end
        else
          add_text(@src.scan(/./))
        end
      end
      define_parser(:span_html, HTML_SPAN_START)

    end
  end
end
