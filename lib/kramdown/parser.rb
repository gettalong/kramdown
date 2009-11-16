# -*- coding: utf-8 -*-

require 'strscan'
require 'stringio'
require 'kramdown/parser/registry'

#TODO: use [[:alpha:]] in all regexp to allow parsing of international values in 1.9.1
#NOTE: use @src.pre_match only before other check/match?/... operations, otherwise the content is changed

module Kramdown

  # This module contains all available parsers. Currently, there is only one parser for parsing
  # documents in kramdown format.
  module Parser

    # Used for parsing a document in kramdown format.
    class Kramdown

      include ::Kramdown

      # Create a new Kramdown parser object for the Kramdown::Document +doc+.
      def initialize(doc)
        @doc = doc
        @src = nil
        @tree = nil
        @unclosed_html_tags = []
        @stack = []
        @used_ids = {}
        @doc.parse_infos[:ald] = {}
        @doc.parse_infos[:link_defs] = {}
        @doc.parse_infos[:footnotes] = {}
      end
      private :initialize

      # Parse the string +source+ using the Kramdown::Document +doc+ and return the parse tree.
      def self.parse(source, doc)
        self.new(doc).parse(source)
      end

      # The source string provided on initialization is parsed and the created +tree+ is returned.
      def parse(source)
        configure_parser
        tree = Element.new(:root)
        parse_blocks(tree, adapt_source(source))
        update_tree(tree)
        @doc.parse_infos[:footnotes].each do |name, data|
          update_tree(data[:content])
        end
        tree
      end

      #######
      private
      #######

      BLOCK_PARSERS = [:blank_line, :codeblock, :codeblock_fenced, :blockquote, :atx_header,
                       :setext_header, :horizontal_rule, :list, :link_definition, :block_html,
                       :footnote_definition, :ald, :block_ial, :extension_block, :eob_marker, :paragraph]
      SPAN_PARSERS =  [:emphasis, :codespan, :autolink, :span_html, :footnote_marker, :link,
                       :span_ial, :html_entity, :typographic_syms, :special_html_chars, :line_break, :escaped_chars,]

      # Adapt the object to allow parsing like specified in the options.
      def configure_parser
        @parsers = {}
        BLOCK_PARSERS.each do |name|
          if Registry.has_parser?(name, :block)
            extend(Registry.parser(name).module)
            @parsers[name] = Registry.parser(name)
          else
            raise "Unknown block parser: #{name}"
          end
        end
        SPAN_PARSERS.each do |name|
          if Registry.has_parser?(name, :span)
            extend(Registry.parser(name).module)
            @parsers[name] = Registry.parser(name)
          else
            raise "Unknown span parser: #{name}"
          end
        end
        @span_start = Regexp.union(*SPAN_PARSERS.map {|name| @parsers[name].start_re})
        @span_start_re = /(?=#{@span_start})/
      end

      # Parse all block level elements in +text+ (a string or a StringScanner object) into the
      # element +el+.
      def parse_blocks(el, text)
        @stack.push([@tree, @src, @unclosed_html_tags])
        @tree, @src, @unclosed_html_tags = el, StringScanner.new(text), []

        while !@src.eos?
          BLOCK_PARSERS.any? do |name|
            if @src.check(@parsers[name].start_re)
              send(@parsers[name].method)
            else
              false
            end
          end || begin
            warning('Warning: no block parser handled the line')
            add_text(@src.scan(/.*\n/))
          end
        end

        @unclosed_html_tags.each do |tag|
          warning("Automatically closing unclosed html tag '#{tag.value}'")
        end

        @tree, @src, @unclosed_html_tags = *@stack.pop
      end

      # Update the tree by parsing all <tt>:text</tt> elements with the span level parser (resets
      # +@tree+, +@src+ and the +@stack+) and by updating the attributes from the IALs.
      def update_tree(element)
        element.children.map! do |child|
          if child.type == :text
            @stack, @tree = [], nil
            @src = StringScanner.new(child.value)
            parse_spans(child)
            child.children
          else
            update_tree(child)
            update_attr_with_ial(child.options[:attr] ||= {}, child.options[:ial]) if child.options[:ial]
            child
          end
        end.flatten!
      end

      # Parse all span level elements in the source string.
      def parse_spans(el, stop_re = nil)
        @stack.push(@tree)
        @tree = el

        used_re = (stop_re.nil? ? @span_start_re : /(?=#{Regexp.union(stop_re, @span_start)})/)
        stop_re_found = false
        while !@src.eos? && !stop_re_found
          if result = @src.scan_until(used_re)
            add_text(result)
            if stop_re && (stop_re_matched = @src.check(stop_re))
              stop_re_found = (block_given? ? yield : true)
            end
            processed = SPAN_PARSERS.any? do |name|
              if @src.check(@parsers[name].start_re)
                send(@parsers[name].method)
                true
              else
                false
              end
            end unless stop_re_found
            if !processed && !stop_re_found
              if stop_re_matched
                add_text(@src.scan(/./))
              else
                raise('Bug: this should not occur - please report!')
              end
            end
          else
            add_text(@src.scan_until(/.*/m)) unless stop_re
            break
          end
        end

        @tree = @stack.pop

        stop_re_found
      end

      # Modify the string +source+ to be usable by the parser.
      def adapt_source(source)
        source.gsub(/\r\n?/, "\n").chomp + "\n"
      end

      # Add the given warning +text+ to the warning array of the Kramdown document.
      def warning(text)
        @doc.warnings << text
        #TODO: add position information
      end

      # This helper method adds the given +text+ either to the last element in the +tree+ if it is a
      # text element or creates a new text element.
      def add_text(text, tree = @tree)
        if tree.children.last && tree.children.last.type == :text
          tree.children.last.value << text
        elsif !text.empty?
          tree.children << Element.new(:text, text)
        end
      end

    end


    module ParserMethods

      INDENT = /^(?:\t| {4})/
      OPT_SPACE = / {0,3}/


      # Parse the string +str+ and extract all attributes and add all found attributes to the hash
      # +opts+.
      def parse_attribute_list(str, opts)
        str.scan(ALD_TYPE_ANY).each do |key, sep, val, id_attr, class_attr, ref|
          if ref
            (opts[:refs] ||= []) << ref
          elsif class_attr
            opts['class'] = ((opts['class'] || '') + " #{class_attr}").lstrip
          elsif id_attr
            opts['id'] = id_attr
          else
            opts[key] = val.gsub(/\\(\}|#{sep})/, "\\1")
          end
        end
      end

      # Update the +ial+ with the information from the inline attribute list +opts+.
      def update_ial_with_ial(ial, opts)
        (ial[:refs] ||= []) << opts[:refs]
        ial['class'] = ((ial['class'] || '') + " #{opts['class']}").lstrip if opts['class']
        opts.each {|k,v| ial[k] = v if k != :refs && k != 'class' }
      end

      # Update the attributes with the information from the inline attribute list and all referenced ALDs.
      def update_attr_with_ial(attr, ial)
        ial[:refs].each do |ref|
          update_attr_with_ial(attr, ref) if ref = @doc.parse_infos[:ald][ref]
        end if ial[:refs]
        attr['class'] = ((attr['class'] || '') + " #{ial['class']}").lstrip if ial['class']
        ial.each {|k,v| attr[k] = v if k.kind_of?(String) && k != 'class' }
      end

      # Generate an alpha-numeric ID from the the string +str+.
      def generate_id(str)
        gen_id = str.gsub(/[^a-zA-Z0-9 -]/, '').gsub(/^[^a-zA-Z]*/, '').gsub(' ', '-').downcase
        gen_id = 'section' if gen_id.length == 0
        if @used_ids.has_key?(gen_id)
          gen_id += '-' + (@used_ids[gen_id] += 1).to_s
        else
          @used_ids[gen_id] = 0
        end
        gen_id
      end

      # Helper method for obfuscating the +email+ address by using HTML entities.
      def obfuscate_email(email)
        result = ""
        email.each_byte do |b|
          result += (b > 128 ? b.chr : "&#%03d;" % b)
        end
        result
      end


      BLANK_LINE = /(?:^\s*\n)+/

      # Parse the blank line at the current postition.
      def parse_blank_line
        @src.pos += @src.matched_size
        if @tree.children.last && @tree.children.last.type == :blank
          @tree.children.last.value += @src.matched
        else
          @tree.children << Element.new(:blank, @src.matched)
        end
        true
      end
      Registry.define_parser(:block, :blank_line, BLANK_LINE, self)


      EOB_MARKER = /^\^\s*?\n/

      # Parse the EOB marker at the current location.
      def parse_eob_marker
        @src.pos += @src.matched_size
        true
      end
      Registry.define_parser(:block, :eob_marker, EOB_MARKER, self)


      PARAGRAPH_START = /^#{OPT_SPACE}[^ \t].*?\n/

      # Parse the paragraph at the current location.
      def parse_paragraph
        @src.pos += @src.matched_size
        if @tree.children.last && @tree.children.last.type == :p
          @tree.children.last.children.first.value << "\n" << @src.matched.chomp
        else
          @tree.children << Element.new(:p)
          add_text(@src.matched.lstrip.chomp, @tree.children.last)
        end
        true
      end
      Registry.define_parser(:block, :paragraph, PARAGRAPH_START, self)


      SETEXT_HEADER_START = /^(#{OPT_SPACE}[^ \t].*?)\n(-|=)+\s*?\n/

      # Parse the Setext header at the current location.
      def parse_setext_header
        if @tree.children.last && @tree.children.last.type != :blank
          return false
        end
        @src.pos += @src.matched_size
        text, level = @src[1].strip, @src[2]
        el = Element.new(:header, nil, :level => (level == '-' ? 2 : 1))
        add_text(text, el)
        el.options[:attr] = {:id => generate_id(text)} if @doc.options[:auto_ids]
        @tree.children << el
        true
      end
      Registry.define_parser(:block, :setext_header, SETEXT_HEADER_START, self)


      ATX_HEADER_START = /^\#{1,6}/
      ATX_HEADER_MATCH = /^(\#{1,6})(.+?)\s*?#*\s*?\n/

      # Parse the Atx header at the current location.
      def parse_atx_header
        if @tree.children.last && @tree.children.last.type != :blank
          return false
        end
        result = @src.scan(ATX_HEADER_MATCH)
        level, text = @src[1], @src[2].strip
        el = Element.new(:header, nil, :level => level.length)
        add_text(text, el)
        el.options[:attr] = {:id => generate_id(text)} if @doc.options[:auto_ids]
        @tree.children << el
        true
      end
      Registry.define_parser(:block, :atx_header, ATX_HEADER_START, self)


      BLOCKQUOTE_START = /^#{OPT_SPACE}> ?/
      BLOCKQUOTE_MATCH = /(^#{OPT_SPACE}>.*?\n)+/

      # Parse the blockquote at the current location.
      def parse_blockquote
        result = @src.scan(BLOCKQUOTE_MATCH).gsub(BLOCKQUOTE_START, '')
        el = Element.new(:blockquote)
        @tree.children << el
        parse_blocks(el, result)
        true
      end
      Registry.define_parser(:block, :blockquote, BLOCKQUOTE_START, self)


      CODEBLOCK_START = INDENT
      CODEBLOCK_MATCH = /(?:#{INDENT}.*?\S.*?\n)+/

      # Parse the indented codeblock at the current location.
      def parse_codeblock
        result = @src.scan(CODEBLOCK_MATCH).gsub(INDENT, '')
        children = @tree.children
        if children.length >= 2 && children[-1].type == :blank && children[-2].type == :codeblock
          children[-2].value << children[-1].value.gsub(INDENT, '') << result
          children.pop
        else
          @tree.children << Element.new(:codeblock, result)
        end
        true
      end
      Registry.define_parser(:block, :codeblock, CODEBLOCK_START, self)


      FENCED_CODEBLOCK_START = /^~{3,}/
      FENCED_CODEBLOCK_MATCH = /^(~{3,})\s*?\n(.*?)^\1~*\s*?\n/m

      # Parse the fenced codeblock at the current location.
      def parse_codeblock_fenced
        if @src.check(FENCED_CODEBLOCK_MATCH)
          @src.pos += @src.matched_size
          @tree.children << Element.new(:codeblock, @src[2])
          true
        else
          false
        end
      end
      Registry.define_parser(:block, :codeblock_fenced, FENCED_CODEBLOCK_START, self)


      HR_START = /^#{OPT_SPACE}(\*|-|_) *\1 *\1 *(\1| )*\n/

      # Parse the horizontal rule at the current location.
      def parse_horizontal_rule
        @src.pos += @src.matched_size
        @tree.children << Element.new(:hr)
        true
      end
      Registry.define_parser(:block, :horizontal_rule, HR_START, self)


      LIST_START_UL = /^(#{OPT_SPACE}[+*-])([\t| ].*?\n)/
      LIST_START_OL = /^(#{OPT_SPACE}\d+\.)([\t| ].*?\n)/
      LIST_START = /#{LIST_START_UL}|#{LIST_START_OL}/

      # Parse the ordered or unordered list at the current location.
      def parse_list
        if @tree.children.last && @tree.children.last.type == :p # last element must not be a paragraph
          return false
        end

        type, list_start_re = (@src.check(LIST_START_UL) ? [:ul, LIST_START_UL] : [:ol, LIST_START_OL])
        list = Element.new(type)

        item = nil
        indent_re = nil
        content_re = nil
        eob_found = false
        nested_list_found = false
        while !@src.eos?
          if @src.check(HR_START)
            break
          elsif @src.scan(list_start_re)
            indentation, content = @src[1].length, @src[2]
            item = Element.new(:li)
            list.children << item
            if content =~ /^\s*\n/
              indentation = 4
            else
              while content =~ /^ *\t/
                temp = content.scan(/^ */).first.length + indentation
                content.sub!(/^( *)(\t+)/) {$1 + " "*(4 - (temp % 4)) + " "*($2.length - 1)*4}
              end
              indentation += content.scan(/^ */).first.length
            end
            content.sub!(/^\s*/, '')
            item.value = content

            indent_re = /^ {#{indentation}}/
            content_re = /^(?:(?:\t| {4}){#{indentation / 4}} {#{indentation % 4}}|(?:\t| {4}){#{indentation / 4 + 1}}).*?\n/
            list_start_re = (type == :ul ? /^( {0,#{[3, indentation - 1].min}}[+*-])([\t| ].*?\n)/ :
                             /^( {0,#{[3, indentation - 1].min}}\d+\.)([\t| ].*?\n)/)
            nested_list_found = false
          elsif result = @src.scan(content_re)
            result.sub!(/^(\t+)/) { " "*4*($1 ? $1.length : 0) }
            result.sub!(indent_re, '')
            if !nested_list_found && result =~ LIST_START
              parse_blocks(item, item.value)
              if item.children.length == 1 && item.children.first.type == :p
                item.value = ''
              else
                item.children.clear
              end
              nested_list_found = true
            end
            item.value << result
          elsif result = @src.scan(BLANK_LINE)
            nested_list_found = true
            item.value << result
          elsif @src.scan(EOB_MARKER)
            eob_found = true
            break
          else
            break
          end
        end

        @tree.children << list

        last = nil
        list.children.each do |item|
          temp = Element.new(:temp)
          parse_blocks(temp, item.value)
          item.children += temp.children
          item.value = nil
          next if item.children.size == 0

          if item.children.first.type == :p && (item.children.length < 2 || item.children[1].type != :blank ||
                                                (item == list.children.last && item.children.length == 2 && !eob_found))
            text = item.children.shift.children.first
            text.value += "\n" if !item.children.empty? && item.children[0].type != :blank
            item.children.unshift(text)
          else
            item.options[:first_as_block] = true
          end

          if item.children.last.type == :blank
            last = item.children.pop
          else
            last = nil
          end
        end

        @tree.children << last if !last.nil? && !eob_found

        true
      end
      Registry.define_parser(:block, :list, LIST_START, self)


      PUNCTUATION_CHARS = "_.:,;!?-"
      LINK_ID_CHARS = /[a-zA-Z0-9 #{PUNCTUATION_CHARS}]/
      LINK_ID_NON_CHARS = /[^a-zA-Z0-9 #{PUNCTUATION_CHARS}]/
      LINK_DEFINITION_START = /^#{OPT_SPACE}\[(#{LINK_ID_CHARS}+)\]:[ \t]*(?:<(.*?)>|([^\s]+))[ \t]*?(?:\n?[ \t]*?(["'])(.+?)\4[ \t]*?)?\n/

      # Parse the link definition at the current location.
      def parse_link_definition
        @src.pos += @src.matched_size
        link_id, link_url, link_title = @src[1].downcase, @src[2] || @src[3], @src[5]
        warning("Duplicate link ID '#{link_id}' - overwriting") if @doc.parse_infos[:link_defs][link_id]
        @doc.parse_infos[:link_defs][link_id] = [link_url, link_title]
        true
      end
      Registry.define_parser(:block, :link_definition, LINK_DEFINITION_START, self)


      ALD_ID_CHARS = /[\w\d-]/
      ALD_ANY_CHARS = /\\\}|[^\}]/
      ALD_ID_NAME = /(?:\w|\d)#{ALD_ID_CHARS}*/
      ALD_TYPE_KEY_VALUE_PAIR = /(#{ALD_ID_NAME})=("|')((?:\\\}|\\\2|[^\}\2])+?)\2/
      ALD_TYPE_CLASS_NAME = /\.(#{ALD_ID_NAME})/
      ALD_TYPE_ID_NAME = /#(#{ALD_ID_NAME})/
      ALD_TYPE_REF = /(#{ALD_ID_NAME})/
      ALD_TYPE_ANY = /(?:\A|\s)(?:#{ALD_TYPE_KEY_VALUE_PAIR}|#{ALD_TYPE_ID_NAME}|#{ALD_TYPE_CLASS_NAME}|#{ALD_TYPE_REF})(?=\s|\Z)/
      ALD_START = /^#{OPT_SPACE}\{:(#{ALD_ID_NAME}):(#{ALD_ANY_CHARS}+)\}\s*?\n/

      # Parse the attribute list definition at the current location.
      def parse_ald
        @src.pos += @src.matched_size
        parse_attribute_list(@src[2], @doc.parse_infos[:ald][@src[1]] ||= {})
        true
      end
      Registry.define_parser(:block, :ald, ALD_START, self)


      IAL_BLOCK_START = /^#{OPT_SPACE}\{:(?!:)(#{ALD_ANY_CHARS}+)\}\s*?\n/

      # Parse the inline attribute list at the current location.
      def parse_block_ial
        @src.pos += @src.matched_size
        if @tree.children.last && @tree.children.last.type != :blank
          parse_attribute_list(@src[1], @tree.children.last.options[:ial] ||= {})
        end
        true
      end
      Registry.define_parser(:block, :block_ial, IAL_BLOCK_START, self)


      EXT_BLOCK_START_STR = "^#{OPT_SPACE}\\{::(%s):(:)?(#{ALD_ANY_CHARS}*)\\}\s*?\n"
      EXT_BLOCK_START = /#{EXT_BLOCK_START_STR % ALD_ID_NAME}/

      # Parse the extension block at the current location.
      def parse_extension_block
        @src.pos += @src.matched_size

        ext = @src[1]
        opts = {}
        parse_attribute_list(@src[3], opts)

        if !@doc.extension.public_methods.map {|m| m.to_s}.include?("parse_#{ext}")
          warning("No extension named '#{ext}' found - ignoring extension block")
          ignore = true
        end

        if !@src[2]
          stop_re = /#{EXT_BLOCK_START_STR % ext}/
          if result = @src.scan_until(stop_re)
            parse_attribute_list(@src[3], opts)
            @doc.extension.send("parse_#{ext}", @tree, opts, result.sub!(stop_re, '')) unless ignore
          else
            warning("No ending line for extension block '#{ext}' found")
          end
        elsif !ignore
          @doc.extension.send("parse_#{ext}", @tree, opts, nil)
        end

        true
      end
      Registry.define_parser(:block, :extension_block, EXT_BLOCK_START, self)


      FOOTNOTE_DEFINITION_START = /^#{OPT_SPACE}\[\^(#{ALD_ID_NAME})\]:\s*?(.*?\n(?:#{BLANK_LINE}?#{CODEBLOCK_MATCH})*)/

      # Parse the foot note definition at the current location.
      def parse_footnote_definition
        @src.pos += @src.matched_size

        el = Element.new(:footnote_def)
        parse_blocks(el, @src[2].gsub(INDENT, ''))
        warning("Duplicate footnote name '#{@src[1]}' - overwriting") if @doc.parse_infos[:footnotes][@src[1]]
        (@doc.parse_infos[:footnotes][@src[1]] = {})[:content] = el
      end
      Registry.define_parser(:block, :footnote_definition, FOOTNOTE_DEFINITION_START, self)


      require 'rexml/parsers/baseparser'

      #:stopdoc:
      # The following regexps are based on the ones used by REXML, with some slight modifications.
      #:startdoc:
      HTML_COMMENT_RE = /<!--(.*?)-->/m
      HTML_INSTRUCTION_RE = /<\?(.*?)\?>/m
      HTML_ATTRIBUTE_RE = /\s*(#{REXML::Parsers::BaseParser::UNAME_STR})\s*=\s*(["'])(.*?)\2/
      HTML_TAG_RE = /<((?>#{REXML::Parsers::BaseParser::UNAME_STR}))\s*((?>\s+#{REXML::Parsers::BaseParser::UNAME_STR}\s*=\s*(["']).*?\3)*)\s*(\/)?>/
      HTML_TAG_CLOSE_RE = /<\/(#{REXML::Parsers::BaseParser::NAME_STR})\s*>/


      HTML_PARSE_AS_BLOCK = %w{div blockquote table dl ol ul form fieldset}
      HTML_PARSE_AS_SPAN  = %w{a address b dd dt em h1 h2 h3 h4 h5 h6 legend li p pre span td th}
      HTML_PARSE_AS_RAW   = %w{script math}
      HTML_PARSE_AS = Hash.new {|h,k| h[k] = :span}
      HTML_PARSE_AS_BLOCK.each {|i| HTML_PARSE_AS[i] = :block}
      HTML_PARSE_AS_SPAN.each {|i| HTML_PARSE_AS[i] = :span}
      HTML_PARSE_AS_RAW.each {|i| HTML_PARSE_AS[i] = :raw}

      HTML_BLOCK_ELEMENTS = %w[div p pre h1 h2 h3 h4 h5 h6 hr form fieldset iframe legend script dl ul ol table ins del blockquote address]

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
          if !((@src.check(/^#{OPT_SPACE}#{HTML_TAG_RE}/) && (HTML_BLOCK_ELEMENTS.include?(@src[1]) || @src[1] =~ /:/)) ||
               @src.check(/^#{OPT_SPACE}#{HTML_TAG_CLOSE_RE}/))
            return false
          end

          @src.scan(/^(.*?)\n/)
          line = @src[1]
          temp = nil
          stack = []

          while line.size > 0
            index_start_tag, index_close_tag = line.index(HTML_TAG_RE), line.index(HTML_TAG_CLOSE_RE)
            if index_start_tag && (!index_close_tag || index_start_tag < index_close_tag) && (!temp || temp.options[:parse_type] == :block)
              md = line.match(HTML_TAG_RE)
              break if !(HTML_BLOCK_ELEMENTS.include?(md[1]) || md[1] =~ /:/)

              add_text(md.pre_match + "\n", temp) if temp
              line = md.post_match

              attrs = {}
              md[2].scan(HTML_ATTRIBUTE_RE).each {|name,sep,val| attrs[name] = val}
              el = Element.new(:html_element, md[1], :attr => attrs, :type => :block,
                               :parse_type => HTML_PARSE_AS[md[1]])

              (temp || @tree).children << el
              if !md[4]
                @unclosed_html_tags.push(el)
                stack << temp
                temp = el
              end
            elsif index_close_tag
              md = line.match(HTML_TAG_CLOSE_RE)
              add_text(md.pre_match, temp) if temp

              line = md.post_match
              if @unclosed_html_tags.size > 0 && md[1] == @unclosed_html_tags.last.value
                el = @unclosed_html_tags.pop
                @tree = @stack.pop unless temp
                temp = stack.pop
                if el.options[:parse_type] == :raw
                  raise "Bug: please report" if el.children.size > 1
                  el.children.first.type = :raw if el.children.first
                end
              else
                if HTML_BLOCK_ELEMENTS.include?(md[1]) && (temp || @tree).options[:parse_type] == :block
                  warning("Found invalidly nested HTML closing tag for '#{md[1]}'")
                end
                if temp
                  add_text(md.to_s, temp)
                else
                  add_text(md.to_s + "\n")
                end
              end
            else
              if temp
                add_text(line, temp)
              else
                warning("Ignoring characters at the end of an HTML block line")
              end
              line = ''
            end
          end
          if temp && temp.children.last && temp.children.last.type == :text
            temp.children.last.value << "\n"
          end
          if temp
            if temp.options[:parse_type] == :span || temp.options[:parse_type] == :raw
              result = @src.scan_until(/(?=#{HTML_BLOCK_START})|\Z/)
              add_text(result, temp)
            end
            @stack.push(@tree)
            @tree = temp
          end
          true
        end
      end
      Registry.define_parser(:block, :block_html, HTML_BLOCK_START, self)




      ESCAPED_CHARS = /\\([\\.*_+-`()\[\]{}#!])/

      # Parse the backslash-escaped character at the current location.
      def parse_escaped_chars
        @src.pos += @src.matched_size
        add_text(@src[1])
      end
      Registry.define_parser(:span, :escaped_chars, ESCAPED_CHARS, self)


      # Parse the HTML entity at the current location.
      def parse_html_entity
        @src.pos += @src.matched_size
        add_text(@src.matched)
      end
      Registry.define_parser(:span, :html_entity, REXML::Parsers::BaseParser::REFERENCE_RE, self)


      SPECIAL_HTML_CHARS = /&|>|</

      # Parse the special HTML characters at the current location.
      def parse_special_html_chars
        @src.pos += @src.matched_size
        add_text(@src.matched)
      end
      Registry.define_parser(:span, :special_html_chars, SPECIAL_HTML_CHARS, self)


      LINE_BREAK = /(  |\\\\)(?=\n)/

      # Parse the line break at the current location.
      def parse_line_break
        @src.pos += @src.matched_size
        @tree.children << Element.new(:br)
      end
      Registry.define_parser(:span, :line_break, LINE_BREAK, self)


      TYPOGRAPHIC_SYMS = [['---', '&mdash;'], ['--', '&ndash;'], ['...', '&hellip;'],
                          ['\\<<', '&lt;&lt;'], ['\\>>', '&gt;&gt;'],
                          ['<< ', '&laquo;&nbsp;'], [' >>', '&nbsp;&raquo;'],
                          ['<<', '&laquo;'], ['>>', '&raquo;']]
      TYPOGRAPHIC_SYMS_SUBST = Hash[*TYPOGRAPHIC_SYMS.flatten]
      TYPOGRAPHIC_SYMS_RE = /#{TYPOGRAPHIC_SYMS.map {|k,v| Regexp.escape(k)}.join('|')}/

      # Parse the typographic symbols at the current location.
      def parse_typographic_syms
        @src.pos += @src.matched_size
        add_text(TYPOGRAPHIC_SYMS_SUBST[@src.matched].dup)
      end
      Registry.define_parser(:span, :typographic_syms, TYPOGRAPHIC_SYMS_RE, self)


      AUTOLINK_START = /<((mailto|https?|ftps?):.*?|.*?@.*?)>/

      # Parse the autolink at the current location.
      def parse_autolink
        @src.pos += @src.matched_size

        text = href = @src[1]
        if @src[2].nil? || @src[2] == 'mailto'
          text = obfuscate_email(@src[2] ? @src[1].sub(/^mailto:/, '') : @src[1])
          mailto = obfuscate_email('mailto')
          href = "#{mailto}:#{text}"
        end
        el = Element.new(:a, nil, {:attr => {'href' => href}})
        add_text(text, el)
        @tree.children << el
      end
      Registry.define_parser(:span, :autolink, AUTOLINK_START, self)


      CODESPAN_DELIMITER = /`+/

      # Parse the codespan at the current scanner location.
      def parse_codespan
        result = @src.scan(CODESPAN_DELIMITER)
        simple = (result.length == 1)
        reset_pos = @src.pos

        if simple && @src.pre_match =~ /\s\Z/ && @src.match?(/\s/)
          add_text(result)
          return
        end

        text = @src.scan_until(/#{result}/)
        if text
          text.sub!(/#{result}\Z/, '')
          if !simple
            text = text[1..-1] if text[0..0] == ' '
            text = text[0..-2] if text[-1..-1] == ' '
          end
          @tree.children << Element.new(:codespan, text)
        else
          @src.pos = reset_pos
          add_text(result)
        end
      end
      Registry.define_parser(:span, :codespan, CODESPAN_DELIMITER, self)


      IAL_SPAN_START = /\{:(#{ALD_ANY_CHARS}+)\}/

      # Parse the inline attribute list at the current location.
      def parse_span_ial
        @src.pos += @src.matched_size
        if @tree.children.last && @tree.children.last.type != :text
          attr = {}
          parse_attribute_list(@src[1], attr)
          update_ial_with_ial(@tree.children.last.options[:ial] ||= {}, attr)
          update_attr_with_ial(@tree.children.last.options[:attr] ||= {}, attr)
        else
          warning("Ignoring span IAL because preceding element is just text")
          add_text(@src.matched)
        end
      end
      Registry.define_parser(:span, :span_ial, IAL_SPAN_START, self)


      FOOTNOTE_MARKER_START = /\[\^(#{ALD_ID_NAME})\]/

      # Parse the footnote marker at the current location.
      def parse_footnote_marker
        @src.pos += @src.matched_size
        fn_def = @doc.parse_infos[:footnotes][@src[1]]
        if fn_def
          valid = fn_def[:marker] && fn_def[:marker].options[:stack][0..-2].zip(fn_def[:marker].options[:stack][1..-1]).all? do |par, child|
            par.children.include?(child)
          end
          if !fn_def[:marker] || !valid
            fn_def[:marker] = Element.new(:footnote, nil, :name => @src[1])
            fn_def[:marker].options[:stack] = [@stack, @tree, fn_def[:marker]].flatten.compact
            @tree.children << fn_def[:marker]
          else
            warning("Footnote marker '#{@src[1]}' already appeared in document, ignoring newly found marker")
            add_text(@src.matched)
          end
        else
          warning("Footnote definition for '#{@src[1]}' not found")
          add_text(@src.matched)
        end
      end
      Registry.define_parser(:span, :footnote_marker, FOOTNOTE_MARKER_START, self)


      EMPHASIS_START = /(?:\*\*?|__?)/

      # Parse the emphasis at the current location.
      def parse_emphasis
        result = @src.scan(EMPHASIS_START)
        element = (result.length == 2 ? :strong : :em)
        type = (result =~ /_/ ? '_' : '*')
        reset_pos = @src.pos

        if (type == '_' && @src.pre_match =~ /[[:alpha:]]\Z/ && @src.check(/[[:alpha:]]/)) || @src.check(/\s/)
          add_text(result)
          return
        end

        delim, elem, run = result, element, 1
        begin
          #p [:bef, @stack.size, delim, elem, @src.pos, @src.peek(20), run]
          el = Element.new(elem)
          stop_re = /#{Regexp.escape(delim)}/
          found = parse_spans(el, stop_re) do
            tempp = (@src.string[@src.pos-1, 1] !~ /\s/) &&
              (elem != :em || !@src.match?(/#{Regexp.escape(delim*2)}(?!#{Regexp.escape(delim)})/)) &&
              (type != '_' || !@src.match?(/#{Regexp.escape(delim)}[[:alpha:]]/)) && el.children.size > 0
            #p [:stp, @stack.size, delim, elem, @src.pos, @src.peek(20), run, tempp]
            tempp
          end
          if !found && elem == :strong
            @src.pos = reset_pos - 1
            delim = type
            elem = :em
            #p [:dat, @stack.size, delim, elem, @src.pos, @src.peek(20), run]
            run += 1
          else
            run = 3
          end
        end until found || run > 2
        #p [:aft, @stack.size, found, delim, elem, run, el]
        if found
          @src.scan(stop_re)
          @tree.children << el
        else
          @src.pos = reset_pos
          add_text(result)
        end
      end
      Registry.define_parser(:span, :emphasis, EMPHASIS_START, self)


      HTML_SPAN_START = /<(#{REXML::Parsers::BaseParser::UNAME_STR}|\?|!--)/

      # Parse the HTML at the current position as span level HTML.
      def parse_span_html
        if result = @src.scan(HTML_COMMENT_RE)
          @tree.children << Element.new(:html_raw, result, :type => :span)
        elsif result = @src.scan(HTML_INSTRUCTION_RE)
          @tree.children << Element.new(:html_raw, result, :type => :span)
        elsif result = @src.scan(HTML_TAG_RE)
          reset_pos = @src.pos
          attrs = {}
          @src[2].scan(HTML_ATTRIBUTE_RE).each {|name,sep,val| attrs[name] = val}
          el = Element.new(:html_element, @src[1], :attr => attrs, :type => :span)
          if @src[4]
            @tree.children << el
          else
            stop_re = /<\/#{Regexp.escape(@src[1])}\s*>/
            if parse_spans(el, stop_re)
              @src.scan(stop_re)
              @tree.children << el
            else
              @src.pos = reset_pos
              add_text(result)
            end
          end
        else
          add_text(@src.scan(/./))
        end
      end
      Registry.define_parser(:span, :span_html, HTML_BLOCK_START, self)


      LINK_TEXT_BRACKET_RE = /\\\[|\\\]|\[|\]/
      LINK_INLINE_ID_RE = /\s*?\[(#{LINK_ID_CHARS}+)?\]/
      LINK_INLINE_TITLE_RE = /\s*?(["'])(.+?)\1\s*?\)/

      LINK_START = /!?\[(?=[^^])/

      # Parse the link at the current scanner position. This method is used to parse normal links as
      # well as image links.
      def parse_link
        result = @src.scan(LINK_START)
        reset_pos = @src.pos

        # no nested links allowed
        if @tree.type == :img || @tree.type == :a || @stack.any? {|t,s| t && (t.type == :img || t.type == :a)}
          add_text(result)
          return
        end

        link_type = (result =~ /^!/ ? :img : :a)
        el = Element.new(link_type)

        stop_re = /\]|!?\[/
        count = 1
        found = parse_spans(el, stop_re) do
          case @src.matched
          when "[", "!["
            count += 1
          when "]"
            count -= 1
          end
          count == 0
        end
        if !found || el.children.empty?
          @src.pos = reset_pos
          add_text(result)
          return
        end

        alt_text = @src.string[reset_pos...@src.pos]
        conv_link_id = alt_text.gsub(/(\s|\n)+/m, ' ').gsub(LINK_ID_NON_CHARS, '').downcase
        @src.scan(stop_re)

        # reference style link or no link url
        if @src.scan(LINK_INLINE_ID_RE) || !@src.check(/\(/)
          link_id = (@src[1] || conv_link_id).downcase
          if @doc.parse_infos[:link_defs].has_key?(link_id)
            add_link(el, @doc.parse_infos[:link_defs][link_id].first, @doc.parse_infos[:link_defs][link_id].last, alt_text)
          else
            warning("No link definition for link ID '#{link_id}' found")
            @src.pos = reset_pos
            add_text(result)
          end
          return
        end

        # link url in parentheses
        if @src.scan(/\(<(.*?)>/)
          link_url = @src[1]
          if @src.scan(/\)/)
            add_link(el, link_url, nil, alt_text)
            return
          end
        else
          link_url = ''
          re = /\(|\)|\s/
          nr_of_brackets = 0
          while temp = @src.scan_until(re)
            link_url += temp
            case @src.matched
            when /\s/
              break
            when '('
              nr_of_brackets += 1
            when ')'
              nr_of_brackets -= 1
              break if nr_of_brackets == 0
            end
          end
          link_url = link_url[1..-2]

          if nr_of_brackets == 0
            add_link(el, link_url, nil, alt_text)
            return
          end
        end

        if @src.scan(LINK_INLINE_TITLE_RE)
          add_link(el, link_url, @src[2], alt_text)
        else
          @src.pos = reset_pos
          add_text(result)
        end
      end
      Registry.define_parser(:span, :link, LINK_START, self)


      # This helper methods adds the approriate attributes to the element +el+ of type +a+ or +img+
      # and the element itself to the <tt>@tree</tt>.
      def add_link(el, href, title, alt_text = nil)
        el.options[:attr] ||= {}
        el.options[:attr]['title'] = title if title
        if el.type == :a
          el.options[:attr]['href'] = href
        else
          el.options[:attr]['src'] = href
          el.options[:attr]['alt'] = alt_text
        end
        @tree.children << el
      end

    end

  end

end
