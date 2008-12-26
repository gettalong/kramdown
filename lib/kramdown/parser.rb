require 'strscan'
require 'rexml/parsers/pullparser'
require 'stringio'

module Kramdown

  class Parser

    State = Struct.new(:tree, :src)

    # Create a new Parser object for the Kramdown::Document +doc+ and the string +source+.
    def initialize(source, doc)
      @doc = doc
      @state = State.new(doc.tree, StringScanner.new(adapt_source(source)))
      @stack = []
      @used_ids = {}
    end

    # Parse the string +source+ provided by the Kramdown::Document +doc+. See Parser#parse.
    def self.parse(source, doc)
      self.new(source, doc).parse
    end

    # The source string provided on initialization is scanned and the +tree+ of the associated
    # document is updated with the result.
    def parse
      #parse_email_header
      parse_blocks
      parse_text_elements(@doc.tree)
      @doc.options[:footnotes].each do |name, data|
        next unless name.kind_of?(String)
        parse_text_elements(data[:content])
      end
    end

    #######
    private
    #######

    # Modify the string +source+ to be usable by the parser.
    def adapt_source(source)
      source.gsub(/\r\n?/, "\n") + "\n\n"
    end

    # Parse all text elements with the span level parser.
    def parse_text_elements(element)
      element.children.map! do |child|
        if child.type == :text
          @state = State.new(child, StringScanner.new(child.value))
          @stack = []
          parse_spans
          child.children
        else
          parse_text_elements(child)
          child
        end
      end.flatten!
    end

    # Parse all block level elements in the source string.
    def parse_blocks
      while !@state.src.eos?
        if @state.src.check(BLANK_LINE)
          parse_blank_line
        elsif @state.src.check(CODEBLOCK_START)
          parse_codeblock
        elsif @state.src.check(TILDE_CODEBLOCK_START)
          parse_codeblock_tilde
        elsif @state.src.check(BLOCKQUOTE_START)
          parse_blockquote
        elsif @state.src.check(SETEXT_HEADER_START)
          parse_setext_header
        elsif @state.src.check(ATX_HEADER_START)
          parse_atx_header
        elsif @state.src.check(HR_START)
          parse_horizontal_rule
        elsif @state.src.check(LIST_START)
          parse_list
        elsif @state.src.check(HTML_BLOCK_START)
          parse_html(:html_block)
        elsif @state.src.check(LINK_DEFINITION_START)
          parse_link_definition
        elsif @state.src.check(FOOTNOTE_DEFINITION_START)
          parse_footnote_definition
        elsif @state.src.check(ALD_START)
          parse_ald
        elsif @state.src.check(IAL_BLOCK_START)
          parse_block_ial
        elsif @state.src.check(EOB_MARKER)
          parse_eob_marker
        elsif @state.src.check(PARAGRAPH_START)
          parse_paragraph
        else
          raise 'Error: unhandled line'
          @state.src.scan(/.*$/)
        end
      end
    end

    # Parse all span level elements in the source string.
    def parse_spans
      while !@state.src.eos?
        if result = @state.src.scan_until(SPAN_START)
          add_text(result)
          if @state.src.check(EMPHASIS_DELIMITER)
            parse_emphasis
          elsif @state.src.check(CODESPAN_DELIMITER)
            parse_codespan
          elsif @state.src.check(AUTOLINK_START)
            parse_autolink
          elsif @state.src.check(HTML_ENTITY)
            parse_html_entity
          elsif @state.src.check(HTML_SPAN_START)
            parse_html(:html_inline)
          elsif @state.src.check(FOOTNOTE_MARKER_START)
            parse_footnote_marker
          elsif @state.src.check(LINK_START)
            parse_link
          elsif @state.src.check(IAL_SPAN_START)
            parse_span_ial
          elsif @state.src.check(SPECIAL_HTML_CHARS)
            parse_special_html_chars
          elsif @state.src.check(ESCAPED_CHAR)
            parse_escape
          elsif @state.src.check(LINE_BREAK)
            parse_line_break
          else
            raise 'Error: this should not occur'
            @state.src.scan(/./)
          end
        else
          result = @state.src.scan_until(/.*/m)
          add_text(result)
        end
      end
    end

    # Parse the optional email headers of the document and add the found options to the associated
    # Kramdown document.
    def parse_email_header
      headers = @state.src.scan(/^(\w[\w\s]*:.*\n)+\n/)
      if headers
        headers = Hash[*headers.split("\n").collect {|l| l.split(/:/).collect {|i| i.strip}}.flatten]
        @doc.options.merge(headers)
      end
    end

    INDENT = /^(?:\t| {4})/
    OPT_SPACE = / {0,3}/
    BLANK_LINE = /(?:^\s*\n)+/

    EOB_MARKER = /^\^\s*?\n/

    PARAGRAPH_START = /^#{OPT_SPACE}[^ \t].*?\n/

    HR_START = /^#{OPT_SPACE}((\*|-|_) *?){3,}\n/

    CODEBLOCK_START = INDENT
    CODEBLOCK_MATCH = /(?:#{INDENT}.*?\n)+/

    TILDE_CODEBLOCK_START = /^~{3,}/
    TILDE_CODEBLOCK_MATCH = /^(~{3,})\s*?\n(.*?)^\1~*\s*?\n/m

    BLOCKQUOTE_START = /^#{OPT_SPACE}> ?/
    BLOCKQUOTE_MATCH = /(^#{OPT_SPACE}>.*?\n)+/

    ATX_HEADER_START = /^\#{1,6}/
    ATX_HEADER_MATCH = /^(\#{1,6})(.+?)\s*?#*\s*?\n/

    SETEXT_HEADER_START = /^(#{OPT_SPACE}[^ \t].*?)\n(-|=)+\s*?\n/

    HTML_BLOCK_ELEMENTS = %w[div p pre h1 h2 h3 h4 h5 h6 hr form script ul ol table ins del]
    HTML_BLOCK_ELEMENTS_RE = Regexp.union(*HTML_BLOCK_ELEMENTS)
    HTML_BLOCK_START = /^#{OPT_SPACE}<(#{HTML_BLOCK_ELEMENTS_RE}|\?|!--)/

    LINK_ID_CHARS = /[a-zA-Z0-9 _.,!?-]/
    LINK_ID_NON_CHARS = /[^a-zA-Z0-9 _.,!?-]/
    LINK_DEFINITION_START = /^#{OPT_SPACE}\[(#{LINK_ID_CHARS}+)\]:[ \t]*([^\s]+)[ \t]*?(?:\n?[ \t]*?(["'])(.+?)\3[ \t]*?)?\n/

    ALD_ID_CHARS = /[\w\d-]/
    ALD_ANY_CHARS = /\\\}|[^\}]/
    ALD_ID_NAME = /(?:\w|\d)#{ALD_ID_CHARS}*/
    ALD_TYPE_KEY_VALUE_PAIR = /(#{ALD_ID_NAME})=("|')((?:\\\}|\\\2|[^\}\2])+?)\2/
    ALD_TYPE_CLASS_NAME = /\.(#{ALD_ID_NAME})/
    ALD_TYPE_ID_NAME = /#(#{ALD_ID_NAME})/
    ALD_TYPE_REF = /(#{ALD_ID_NAME})/
    ALD_TYPE_ANY = /(?:\A|\s)(?:#{ALD_TYPE_KEY_VALUE_PAIR}|#{ALD_TYPE_ID_NAME}|#{ALD_TYPE_CLASS_NAME}|#{ALD_TYPE_REF})(?=\s|\Z)/
    ALD_START = /^#{OPT_SPACE}\{:(#{ALD_ID_NAME}):(#{ALD_ANY_CHARS}+)\}\s*?\n/

    IAL_BLOCK_START = /^#{OPT_SPACE}\{:(#{ALD_ANY_CHARS}+)\}\s*?\n/

    FOOTNOTE_DEFINITION_START = /^#{OPT_SPACE}\[\^(#{ALD_ID_NAME})\]:\s*?(.*?\n(?:#{BLANK_LINE}?#{CODEBLOCK_MATCH})*)/

    LIST_START_UL = /^#{OPT_SPACE}[+*-][\t| ]/
    LIST_START_OL = /^#{OPT_SPACE}\d+\.[\t| ]/
    LIST_START = /#{LIST_START_UL}|#{LIST_START_OL}/
    LIST_END_UL = Regexp.union(HR_START, BLOCKQUOTE_START, ATX_HEADER_START,
                               SETEXT_HEADER_START, HTML_BLOCK_START, FOOTNOTE_DEFINITION_START,
                               LINK_DEFINITION_START, LIST_START_OL, ALD_START, IAL_BLOCK_START)
    LIST_END_OL = Regexp.union(HR_START, BLOCKQUOTE_START, ATX_HEADER_START,
                               SETEXT_HEADER_START, HTML_BLOCK_START, FOOTNOTE_DEFINITION_START,
                               LINK_DEFINITION_START, LIST_START_UL, ALD_START, IAL_BLOCK_START)
    LIST_ITEM_START_UL = /#{LIST_START_UL}.*?\n(#{PARAGRAPH_START})*?(?=#{LIST_START_UL}|#{CODEBLOCK_START}|#{LIST_END_UL}|#{EOB_MARKER}|#{BLANK_LINE}|\Z)/m
    LIST_ITEM_START_OL = /#{LIST_START_OL}.*?\n(#{PARAGRAPH_START})*?(?=#{LIST_START_OL}|#{CODEBLOCK_START}|#{LIST_END_OL}|#{EOB_MARKER}|#{BLANK_LINE}|\Z)/m


    # Parse the blank line at the current postition.
    def parse_blank_line
      @state.src.pos += @state.src.matched_size
      if @state.tree.children.last && @state.tree.children.last.type == :blank
        @state.tree.children.last.value += @state.src.matched
      else
        @state.tree.children << Element.new(:blank, @state.src.matched)
      end
    end

    # Parse the EOB marker at the current location.
    def parse_eob_marker
      @state.src.pos += @state.src.matched_size
      @state.tree.children << Element.new(:eob)
    end

    # Parse the paragraph at the current location.
    def parse_paragraph
      result = @state.src.scan(PARAGRAPH_START)
      if @state.tree.children.last && @state.tree.children.last.type == :p
        @state.tree.children.last.children.first.value << "\n" + result.chomp
      else
        @state.tree.children << Element.new(:p)
        @state.tree.children.last.children << Element.new(:text, result.lstrip.chomp)
      end
    end

    # Parse the indented codeblock at the current location.
    def parse_codeblock
      result = @state.src.scan(CODEBLOCK_MATCH).gsub(INDENT, '')
      children = @state.tree.children
      if children.length >= 2 && children[-1].type == :blank && children[-2].type == :codeblock
        children[-2].value += children[-1].value + result
        children.pop
      else
        @state.tree.children << Element.new(:codeblock, result)
      end
    end

    # Parse the fenced codeblock at the current location.
    def parse_codeblock_tilde
      @state.src.scan(TILDE_CODEBLOCK_MATCH)
      @state.tree.children << Element.new(:codeblock, @state.src[2])
    end

    # Parse the blockquote at the current location.
    def parse_blockquote
      result = @state.src.scan(BLOCKQUOTE_MATCH).gsub(BLOCKQUOTE_START, '')
      el = Element.new(:blockquote)
      @state.tree.children << el

      @stack.push @state
      @state = State.new(el, StringScanner.new(result))
      parse_blocks
      @state = @stack.pop
    end

    # Parse the Atx header at the current location.
    def parse_atx_header
      result = @state.src.scan(ATX_HEADER_MATCH)
      level, text = @state.src[1], @state.src[2]
      el = Element.new(:header, nil, :level => level.length)
      el.children << Element.new(:text, text.strip)
      el.options[:attr] = {:id => generate_id(text.strip)} if @doc.options[:auto_ids]
      @state.tree.children << el
    end

    # Parse the Setext header at the current location.
    def parse_setext_header
      if @state.tree.children.last && @state.tree.children.last.type == :p
        parse_paragraph
        return
      end
      @state.src.pointer += @state.src.matched_size
      text, level = @state.src[1].strip, @state.src[2]
      el = Element.new(:header, nil, :level => (level == '-' ? 2 : 1))
      el.children << Element.new(:text, text)
      el.options[:attr] = {:id => generate_id(text.strip)} if @doc.options[:auto_ids]
      @state.tree.children << el
    end

    # Generate an ID from the the string +str+.
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

    # Parse the horizontal rule at the current location.
    def parse_horizontal_rule
      @state.src.pointer += @state.src.matched_size
      @state.tree.children << Element.new(:hr)
    end

    # Parse the ordered or unordered list at the current location.
    def parse_list
      type, list_start, list_end, item_start = (@state.src.check(LIST_START_UL) ? [:ul, LIST_START_UL, LIST_END_UL, LIST_ITEM_START_UL] : [:ol, LIST_START_OL, LIST_END_OL, LIST_ITEM_START_OL])
      list = Element.new(type)

      if !@state.src.check(/  /) && @state.tree.children.last && @state.tree.children.last.type == :p
        parse_paragraph
        return
      end

      eob_found = false
      while !@state.src.eos?
        if @state.src.check(list_end)
          break
        elsif result = @state.src.scan(item_start)
          item = Element.new(:li)
          result.sub!(list_start, '')
          result.sub!(/\A {1,#{4-$&.length}}/, '') if $&.length < 4

          item.children << Element.new(:text, result)
          list.children << item
        elsif result = @state.src.scan(CODEBLOCK_MATCH)
          result.gsub!(INDENT, '')
          list.children.last.children.last.value += result
        elsif result = @state.src.scan(BLANK_LINE)
          list.children.last.children.last.value += result
        elsif @state.src.scan(EOB_MARKER)
          eob_found = true
          break
        elsif @state.src.check(PARAGRAPH_START)
          break
        else
          raise 'You shouldn\'t be here'
          break
        end
      end

      last = nil
      list.children.each do |item|
        str = item.children.pop.value
        @stack.push @state
        @state = State.new(item, StringScanner.new(str))
        parse_blocks
        @state = @stack.pop

        if item.children.first.type == :p && (item.children.length < 2 || item.children[1].type != :blank ||
                                              (item == list.children.last && item.children.length == 2 && !eob_found))
          text = item.children.shift.children.first
          text.value += "\n" if !item.children.empty? && item.children[0].type != :blank
          item.children.unshift(text)
        else
          item.options[:first_as_block] = true
        end

        if item.children.last.type == :blank
          item.children.pop
          last = :blank
        else
          last = :non_blank
        end
      end

      @state.tree.children << list
      @state.tree.children << Element.new(:blank, "") if last == :blank && !eob_found
    end

    # Parse the HTML tag, XML processing instruction or XML comment at the current location.
    def parse_html(element_type)
      parser = REXML::Parsers::BaseParser.new(@state.src.string[@state.src.pos..-1])
      element = nil
      count = 0
      while parser.has_next?
        res = REXML::Parsers::PullEvent.new(parser.pull) rescue REXML::Parsers::PullEvent.new([:error])
        if res.start_element?
          element = res[0] unless element
          count += 1 if element == res[0]
        elsif res.end_element? && element == res[0]
          count -= 1
          break if count == 0
        elsif element.nil? && (res.comment? || res.instruction?)
          break
        elsif res.error?
          break
        end
      end
      el = Element.new(element_type, @state.src.string[@state.src.pos..(parser.position == 0 ? -1 : @state.src.pos + parser.position - 1)])
      #TODO: ignore invalid HTML?? Right thing to do?
      @state.tree.children << el
      @state.src.pos = (parser.position == 0 ? @state.src.string.length : @state.src.pos + parser.position)
      @state.src.scan(/\n/)
    end

    # Parse the link definition at the current location.
    def parse_link_definition
      @state.src.pos += @state.src.matched_size
      link_id, link_url, link_title = @state.src[1].downcase, @state.src[2], @state.src[4]
      add_warning("Duplicate link ID #{link_id}") if @doc.options[:link_defs][link_id]
      @doc.options[:link_defs][link_id] = [link_url, link_title]
    end

    # Parse the attribute list definition at the current location.
    def parse_ald
      @state.src.pos += @state.src.matched_size
      write_al_content(@state.src[2], @doc.options[:alds][@state.src[1]] ||= {})
    end

    # Parse the inline attribute list at the current location.
    def parse_block_ial
      @state.src.pos += @state.src.matched_size
      if @state.tree.children.last
        write_al_content(@state.src[1], @state.tree.children.last.options[:ial] = {})
      end
    end

    # Parse the foot note definition at the current location.
    def parse_footnote_definition
      @state.src.pos += @state.src.matched_size

      el = Element.new(:root)
      @stack.push @state
      @state = State.new(el, StringScanner.new(@state.src[2].gsub(INDENT, '')))
      parse_blocks
      @state = @stack.pop

      (@doc.options[:footnotes][@state.src[1]] ||= {})[:content] = el
    end

    # Parse the string +str+ and add all found attributes to the hash +opts+.
    def write_al_content(str, opts)
      #TODO: add warning on empty scan
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

    # Add the given warning +text+ to the warning array of the Kramdown document.
    def add_warning(text)
      @doc.options[:warnings] << text
    end

    ESCAPED_CHAR = /\\[^A-Za-z0-9\s]/

    HTML_ENTITY = /\&([\w\d]+|\#x?[\w\d]+);/

    SPECIAL_HTML_CHARS = /\&|>|</

    HTML_SPAN_START = /<(\w+(?::\w+)?(?=\s+?|\/?>)|\?|!--)/

    AUTOLINK_START = /<((mailto|https?|ftps?):.*?|.*?@.*?)>/

    LINK_START = /!?\[(?=[^^])/

    EMPHASIS_DELIMITER = /\*\*?|__?/

    CODESPAN_DELIMITER = /`+/

    LINE_BREAK = /  (?=$)/

    IAL_SPAN_START = /\{:(#{ALD_ANY_CHARS}+)\}/

    FOOTNOTE_MARKER_START = /\[\^(#{ALD_ID_NAME})\]/

    SPAN_START = Regexp.union(/(?=#{EMPHASIS_DELIMITER}|#{CODESPAN_DELIMITER}|#{AUTOLINK_START}|
                                  #{HTML_SPAN_START}|#{FOOTNOTE_MARKER_START}|#{LINK_START}|#{IAL_SPAN_START}|
                                  #{HTML_ENTITY}|#{SPECIAL_HTML_CHARS}|#{ESCAPED_CHAR}|#{LINE_BREAK})/x)

    # Parse the backslash-escaped character at the current location.
    def parse_escape
      @state.src.pointer += @state.src.matched_size
      add_text(@state.src.matched[1..1])
    end

    # Parse the HTML entity at the current location.
    def parse_html_entity
      @state.src.pointer += @state.src.matched_size
      add_text(@state.src.matched)
    end

    # Parse the special HTML characters at the current location.
    def parse_special_html_chars
      @state.src.pointer += @state.src.matched_size
      add_text(@state.src.matched)
    end

    # Parse the line break at the current location.
    def parse_line_break
      @state.src.pointer += @state.src.matched_size
      @state.tree.children << Element.new(:br)
    end

    # Parse the autolink at the current location.
    def parse_autolink
      @state.src.pointer += @state.src.matched_size

      if @state.src[2].nil? || @state.src[2] == 'mailto'
        text = obfuscate_email(@state.src[2] ? @state.src[1].sub(/^mailto:/, '') : @state.src[1])
        mailto = obfuscate_email('mailto')
        add_link(text, "#{mailto}:#{text}", nil, false)
      else
        add_link(@state.src[1], @state.src[1], nil, false)
      end
    end

    # Helper method for obfuscating the +email+ address by using HTML entities.
    def obfuscate_email(email)
      result = ""
      email.each_byte do |b|
        result += (b > 128 ? b.chr : "&#%03d;" % b)
      end
      result
    end

    # Parse the emphasis at the current location.
    def parse_emphasis
      result = @state.src.scan(EMPHASIS_DELIMITER)
      element = (result.length == 2 ? :strong : :em)
      type = (result =~ /_/ ? '_' : '*')
      reset_pos = @state.src.pos

      if @state.src.pre_match =~ /\s\Z/ && @state.src.match?(/\s/)
        add_text(result)
        return
      end

      text = nil
      re = /\s#{Regexp.escape(type)}\s|\\#{Regexp.escape(type)}|#{Regexp.escape(result)}|#{Regexp.escape(type)}/
      nr_of_delims = 0
      while temp = @state.src.scan_until(re)
        text ||= ''
        text += temp
        if @state.src.matched == result
          break
        elsif @state.src.matched == type
          nr_of_delims += 1
        end
      end

      if text && temp
        el = Element.new(element)
        @state.tree.children << el
        remove_re = /#{Regexp.escape(result)}$/

        if element == :strong && @state.src.check(/#{Regexp.escape(type)}/) &&
            (nr_of_delims % 2 == 1)
          text += @state.src.scan(/#{Regexp.escape(type)}/)
        end

        @stack.push @state
        @state = State.new(el, StringScanner.new(text.sub(remove_re, '')))
        parse_spans
        @state = @stack.pop
      else
        @state.src.pos = reset_pos
        add_text(result)
      end
    end

    # Parse the codespan at the current scanner location.
    def parse_codespan
      result = @state.src.scan(CODESPAN_DELIMITER)
      simple = (result.length == 1)
      reset_pos = @state.src.pos

      if simple && @state.src.pre_match =~ /\s\Z/ && @state.src.match?(/\s/)
        add_text(result)
        return
      end

      text = @state.src.scan_until(/#{result}/)
      if text
        text.sub!(/#{result}\Z/, '')
        if !simple
          text = text[1..-1] if text[0..0] == ' '
          text = text[0..-2] if text[-1..-1] == ' '
        end
        @state.tree.children << Element.new(:codespan, text)
      else
        @state.src.pos = reset_pos
        add_text(result)
      end
    end


    LINK_TEXT_BRACKET_RE = /\\\[|\\\]|\[|\]/
    LINK_INLINE_ID_RE = /\s*?\[(#{LINK_ID_CHARS}+)?\]/
    LINK_INLINE_TITLE_RE = /\s*?(["'])(.+?)\1\s*?\)/

    # Parse the link at the current scanner position. This method is used to parse normal links as
    # well as image links.
    def parse_link
      result = @state.src.scan(LINK_START)
      reset_pos = @state.src.pos
      link_add_method = (result =~ /^!/ ? :add_img_link : :add_link)

      link_text = nil
      nr_of_brackets = 1
      while temp = @state.src.scan_until(LINK_TEXT_BRACKET_RE)
        link_text ||= ''
        link_text += temp
        case @state.src.matched
        when '['
          nr_of_brackets += 1
          link_text.insert(-2, "\\")
        when ']'
          nr_of_brackets -= 1
          if nr_of_brackets == 0
            link_text.chop!
            break
          else
            link_text.insert(-2, "\\")
          end
        end
      end

      if !link_text || nr_of_brackets > 0
        @state.src.pos = reset_pos
        add_text(result)
        return
      end

      conv_link_id = link_text.gsub(/\n/, ' ').gsub(LINK_ID_NON_CHARS, '').downcase

      if @state.src.scan(LINK_INLINE_ID_RE)
        link_id = (@state.src[1] || conv_link_id).downcase
        if @doc.options[:link_defs].has_key?(link_id)
          send(link_add_method, link_text, *@doc.options[:link_defs][link_id])
        else
          @state.src.pos = reset_pos
          add_text(result)
        end
        return
      end

      if !@state.src.scan(/\(/)
        if @doc.options[:link_defs].has_key?(conv_link_id)
          send(link_add_method, link_text, *@doc.options[:link_defs][conv_link_id])
        else
          @state.src.pos = reset_pos
          add_text(result)
        end
        return
      end

      link_url = ''
      re = /\(|\)|\s/
      nr_of_brackets = 1
      while temp = @state.src.scan_until(re)
        link_url += temp
        case @state.src.matched
        when /\s/
          break
        when '('
          nr_of_brackets += 1
        when ')'
          nr_of_brackets -= 1
          break if nr_of_brackets == 0
        end
      end
      link_url.chop!

      if nr_of_brackets == 0
        send(link_add_method, link_text, link_url, nil)
        return
      end

      if @state.src.scan(LINK_INLINE_TITLE_RE)
        send(link_add_method, link_text, link_url, @state.src[2])
      else
        @state.src.pos = reset_pos
        add_text(result)
      end
    end

    # Parse the inline attribute list at the current location.
    def parse_span_ial
      @state.src.pos += @state.src.matched_size
      if @state.tree.children.last && @state.tree.children.last.type != :text
        write_al_content(@state.src[1], @state.tree.children.last.options[:ial] = {})
      else
        add_text(@state.src.matched)
      end
    end

    # Parse the footnote marker at the current location.
    def parse_footnote_marker
      @state.src.pos += @state.src.matched_size
      fn_def = @doc.options[:footnotes][@state.src[1]]
      if fn_def && !fn_def[:number]
        fn_def[:number] = @doc.options[:footnotes][:number]
        @doc.options[:footnotes][:number] += 1
        @state.tree.children << Element.new(:footnote, nil, :name => @state.src[1])
      else
        add_text(@state.src.matched)
      end
    end

    # This helper method adds a link with the text +link_text+, the URL +href+ and the optional
    # +title+ to the tree and parses the link_text as span level text if +parse_text+ is +true+.
    def add_link(link_text, href, title = nil, parse_text = true)
      el = Element.new(:a, nil, {
                         :attr => {
                           'title' => title,
                           'href' => href,
                         },
                       })
      @state.tree.children << el

      if parse_text
        @stack.push @state
        @state = State.new(el, StringScanner.new(link_text))
        parse_spans
        @state = @stack.pop
      else
        el.children << Element.new(:text, link_text)
      end
    end

    # This helper methods adds an image link with the alternative text +alt_text+, the image source
    # +src+ and the optional +title+ to the the tree.
    def add_img_link(alt_text, src, title = nil)
      el = Element.new(:img, nil, {
                         :attr => {
                           'alt' => alt_text,
                           'title' => title,
                           'src' => src,
                         },
                       })
      @state.tree.children << el
    end

    # This helper method adds the given +text+ either to the last element in the tree if it is a
    # text element or creates a new text element.
    def add_text(text)
      if @state.tree.children.last && @state.tree.children.last.type == :text
        @state.tree.children.last.value += text
      elsif !text.empty?
        @state.tree.children << Element.new(:text, text)
      end
    end

  end

end
