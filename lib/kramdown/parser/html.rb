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
require 'strscan'

module Kramdown

  module Parser

    # Used for parsing a HTML document.
    class Html < Base

      # Contains all constants that are used when parsing.
      module Constants
        #:stopdoc:
        # The following regexps are based on the ones used by REXML, with some slight modifications.
        HTML_DOCTYPE_RE = /<!DOCTYPE.*?>/m
        HTML_COMMENT_RE = /<!--(.*?)-->/m
        HTML_INSTRUCTION_RE = /<\?(.*?)\?>/m
        HTML_ATTRIBUTE_RE = /\s*(#{REXML::Parsers::BaseParser::UNAME_STR})\s*=\s*(["'])(.*?)\2/m
        HTML_TAG_RE = /<((?>#{REXML::Parsers::BaseParser::UNAME_STR}))\s*((?>\s+#{REXML::Parsers::BaseParser::UNAME_STR}\s*=\s*(["']).*?\3)*)\s*(\/)?>/m
        HTML_TAG_CLOSE_RE = /<\/(#{REXML::Parsers::BaseParser::NAME_STR})\s*>/m
        HTML_ENTITY_RE = /&([\w:][\-\w\d\.:]*);|&#(\d+);|&\#x([0-9a-fA-F]+);/


        HTML_PARSE_AS_BLOCK = %w{applet button blockquote colgroup dd div dl fieldset form iframe li
                               map noscript object ol table tbody thead tfoot tr td ul}
        HTML_PARSE_AS_SPAN  = %w{a abbr acronym address b bdo big cite caption del dfn dt em
                               h1 h2 h3 h4 h5 h6 i ins kbd label legend optgroup p q rb rbc
                               rp rt rtc ruby samp select small span strong sub sup th tt var}
        HTML_PARSE_AS_RAW   = %w{script math option textarea pre code}

        HTML_PARSE_AS = Hash.new {|h,k| h[k] = :raw}
        HTML_PARSE_AS_BLOCK.each {|i| HTML_PARSE_AS[i] = :block}
        HTML_PARSE_AS_SPAN.each {|i| HTML_PARSE_AS[i] = :span}
        HTML_PARSE_AS_RAW.each {|i| HTML_PARSE_AS[i] = :raw}

        # Some HTML elements like script belong to both categories (i.e. are valid in block and
        # span HTML) and don't appear therefore!
        HTML_SPAN_ELEMENTS = %w{a abbr acronym b big bdo br button cite code del dfn em i img input
                              ins kbd label option q rb rbc rp rt rtc ruby samp select small span
                              strong sub sup textarea tt var}
        HTML_BLOCK_ELEMENTS = %w{address article aside applet body button blockquote caption col colgroup dd div dl dt fieldset
                               figcaption footer form h1 h2 h3 h4 h5 h6 header hgroup hr html head iframe legend listing menu
                               li map nav ol optgroup p pre section summary table tbody td th thead tfoot tr ul}
        HTML_ELEMENTS_WITHOUT_BODY = %w{area base br col command embed hr img input keygen link meta param source track wbr}
      end


      # Contains the parsing methods. This module can be mixed into any parser to get HTML parsing
      # functionality. The only thing that must be provided by the class are instance variable
      # <tt>@stack</tt> for storing needed state and <tt>@src</tt> (instance of StringScanner) for
      # the actual parsing.
      module Parser

        include Constants

        # Process the HTML start tag that has already be scanned/checked. Does the common processing
        # steps and then yields to the caller for further processing.
        def handle_html_start_tag
          name = @src[1]
          closed = !@src[4].nil?
          attrs = {}
          @src[2].scan(HTML_ATTRIBUTE_RE).each {|attr,sep,val| attrs[attr] = val}

          el = Element.new(:html_element, name, :attr => attrs, :category => :block)
          @tree.children << el

          if !closed && HTML_ELEMENTS_WITHOUT_BODY.include?(el.value)
            warning("The HTML tag '#{el.value}' cannot have any content - auto-closing it")
            closed = true
          end
          if name == 'script'
            handle_html_script_tag
            yield(el, true)
          else
            yield(el, closed)
          end
        end

        def handle_html_script_tag
          curpos = @src.pos
          if result = @src.scan_until(/(?=<\/script\s*>)/m)
            add_text(extract_string(curpos...@src.pos, @src), @tree.children.last, :raw)
            @src.scan(HTML_TAG_CLOSE_RE)
          else
            add_text(@src.scan(/.*/m), @tree.children.last, :raw)
            warning("Found no end tag for 'script' - auto-closing it")
          end
        end

        HTML_RAW_START = /(?=<(#{REXML::Parsers::BaseParser::UNAME_STR}|\/|!--|\?))/

        # Parse raw HTML from the current source position, storing the found elements in +el+.
        # Parsing continues until one of the following criteria are fulfilled:
        #
        # - The end of the document is reached.
        # - The matching end tag for the element +el+ is found (only used if +el+ is an HTML
        #   element).
        #
        # When an HTML start tag is found, processing is deferred to #handle_html_start_tag,
        # providing the block given to this method.
        def parse_raw_html(el, &block)
          @stack.push(@tree)
          @tree = el

          done = false
          while !@src.eos? && !done
            if result = @src.scan_until(HTML_RAW_START)
              add_text(result, @tree, :text)
              if result = @src.scan(HTML_COMMENT_RE)
                @tree.children << Element.new(:xml_comment, result, :category => :block, :parent_is_raw => true)
              elsif result = @src.scan(HTML_INSTRUCTION_RE)
                @tree.children << Element.new(:xml_pi, result, :category => :block, :parent_is_raw => true)
              elsif @src.scan(HTML_TAG_RE)
                handle_html_start_tag(&block)
              elsif @src.scan(HTML_TAG_CLOSE_RE)
                if @tree.value == @src[1]
                  done = true
                else
                  warning("Found invalidly used HTML closing tag for '#{@src[1]}' - ignoring it")
                end
              else
                add_text(@src.scan(/./), @tree, :text)
              end
            else
              result = @src.scan(/.*/m)
              add_text(result, @tree, :text)
              warning("Found no end tag for '#{@tree.value}' - auto-closing it") if @tree.type == :html_element
              done = true
            end
          end

          @tree = @stack.pop
        end

      end


      # Converts HTML elements to native elements if possible.
      class ElementConverter

        include Constants

        REMOVE_TEXT_CHILDREN =  %w{html head hgroup ol ul dl table colgroup tbody thead tfoot tr select optgroup}
        REMOVE_WHITESPACE_CHILDREN = %w{body section nav article aside header footer address
                                        div li dd blockquote figure figcaption td th fieldset form}
        STRIP_WHITESPACE = %w{address article aside blockquote body caption dd div dl dt fieldset figcaption form footer
                              header h1 h2 h3 h4 h5 h6 legend li nav p section td th}
        SIMPLE_ELEMENTS = %w{em strong blockquote hr br a img p thead tbody tfoot tr td th ul ol dl li dl dt dd}

        # Convert the element +el+ and its children.
        def process(el, convert_simple = true, parent = nil)
          case el.type
          when :xml_comment, :xml_pi, :html_doctype
            ptype = if parent.nil?
                      'div'
                    else
                      case parent.type
                      when :html_element then parent.value
                      when :code_span then 'code'
                      when :code_block then 'pre'
                      when :header then 'h1'
                      else parent.type.to_s
                      end
                    end
            el.options = {:category => HTML_PARSE_AS_SPAN.include?(ptype) ? :span : :block}
            return
          when :html_element
          else return
          end

          type = el.value
          remove_text_children(el) if REMOVE_TEXT_CHILDREN.include?(type)

          mname = "convert_#{el.value}"
          if self.class.method_defined?(mname)
            send(mname, el)
          elsif convert_simple && SIMPLE_ELEMENTS.include?(type)
            set_basics(el, type.intern, HTML_SPAN_ELEMENTS.include?(type) ? :span : :block)
            process_children(el, convert_simple)
          else
            process_html_element(el, convert_simple)
          end

          strip_whitespace(el) if STRIP_WHITESPACE.include?(type)
          remove_whitespace_children(el) if REMOVE_WHITESPACE_CHILDREN.include?(type)
        end

        def process_children(el, convert_simple = true)
          el.children.map! do |c|
            if c.type == :text
              process_text(c.value)
            else
              process(c, convert_simple, el)
              c
            end
          end.flatten!
        end

        # Process the HTML text +raw+: compress whitespace (if +preserve+ is +false+) and convert
        # entities in entity elements.
        def process_text(raw, preserve = false)
          raw.gsub!(/\s+/, ' ') unless preserve
          src = StringScanner.new(raw)
          result = []
          while !src.eos?
            if tmp = src.scan_until(/(?=#{HTML_ENTITY_RE})/)
              result << Element.new(:text, tmp)
              src.scan(HTML_ENTITY_RE)
              val = src[1] || (src[2] && src[2].to_i) || src[3].hex
              result << if %w{lsquo rsquo ldquo rdquo}.include?(val)
                          Element.new(:smart_quote, val.intern)
                        elsif %w{mdash ndash hellip laquo raquo}.include?(val)
                          Element.new(:typographic_sym, val.intern)
                        else
                          Element.new(:entity, val)
                        end
            else
              result << Element.new(:text, src.scan(/.*/m))
            end
          end
          result
        end

        def process_html_element(el, convert_simple = true)
          el.options = {:category => HTML_SPAN_ELEMENTS.include?(el.value) ? :span : :block,
            :parse_type => HTML_PARSE_AS[el.value],
            :attr => el.options[:attr]
          }
          process_children(el, convert_simple)
        end

        def remove_text_children(el)
          el.children.delete_if {|c| c.type == :text}
        end

        def strip_whitespace(el)
          return if el.children.empty?
          if el.children.first.type == :text
            el.children.first.value.lstrip!
          end
          if el.children.last.type == :text
            el.children.last.value.rstrip!
          end
        end

        def remove_whitespace_children(el)
          i = -1
          el.children.delete_if do |c|
            i += 1
            c.type == :text && c.value.strip.empty? &&
              (i == 0 || i == el.children.length - 1 || (el.children[i-1].options[:category] == :block &&
                                                         el.children[i+1].options[:category] == :block))
          end
        end

        def set_basics(el, type, category, opts = {})
          el.type = type
          el.options = {:category => category, :attr => el.options[:attr]}.merge(opts)
          el.value = nil
        end

        def extract_text(el, raw)
          raw << el.value.to_s if el.type == :text
          el.children.each {|c| extract_text(c, raw)}
        end

        def convert_h1(el)
          set_basics(el, :header, :block, :level => el.value[1..1].to_i)
          extract_text(el, el.options[:raw_text] = '')
          process_children(el)
        end
        %w{h2 h3 h4 h5 h6}.each {|i| alias_method("convert_#{i}".intern, :convert_h1)}

        def convert_code(el)
          if el.value == 'code'
            set_basics(el, :codespan, :span)
          else
            set_basics(el, :codeblock, :block)
          end
          raw = ''
          extract_text(el, raw)
          result = process_text(raw, true)
          if result.length > 1 || result.first.type != :text
            el.children = result
          else
            el.value = result.first.value
          end
        end
        alias :convert_pre :convert_code

        def convert_table(el)
          if !is_simple_table?(el)
            process_html_element(el, false)
            return
          end
          process_children(el)
          set_basics(el, :table, :block)
          el.options[:alignment] = []
          helper = lambda do |c|
            if c.type == :tr && el.options[:alignment].empty?
              el.options[:alignment] = [:default] * c.children.length
              break
            else
              c.children.each {|cc| helper.call(cc)}
            end
          end
          helper.call(el)
          true
        end

        def is_simple_table?(el)
          only_phrasing_content = lambda do |c|
            c.children.all? do |cc|
              (cc.type == :text || !HTML_BLOCK_ELEMENTS.include?(cc.value)) && only_phrasing_content.call(cc)
            end
          end
          helper = Proc.new do |c|
            if c.value == 'th' || c.value == 'td'
              return false if !only_phrasing_content.call(c)
            else
              c.children.each {|cc| helper.call(cc)}
            end
          end
          helper.call(el)
          true
        end

      end

      include Parser

      # Parse +source+ as HTML document and return the created +tree+.
      def parse(source)
        @stack = []
        @tree = Element.new(:root)
        @src = StringScanner.new(adapt_source(source))

        while true
          if result = @src.scan(/\s*#{HTML_INSTRUCTION_RE}/)
            @tree.children << Element.new(:xml_pi, result.strip, :category => :block)
          elsif result = @src.scan(/\s*#{HTML_DOCTYPE_RE}/)
            @tree.children << Element.new(:html_doctype, result.strip, :category => :block)
          elsif result = @src.scan(/\s*#{HTML_COMMENT_RE}/)
            @tree.children << Element.new(:xml_comment, result.strip, :category => :block)
          else
            break
          end
        end

        tag_handler = lambda do |c, closed|
          parse_raw_html(c, &tag_handler) if !closed
        end
        parse_raw_html(@tree, &tag_handler)

        ec = ElementConverter.new
        @tree.children.each {|c| ec.process(c)}
        ec.remove_whitespace_children(@tree)
        @tree
      end

    end

  end

end
