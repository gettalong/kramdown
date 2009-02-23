module Kramdown

  module Converter

    class ToHtml

      # Initialize the HTML converter with the given Kramdown document +doc+ and the element +tree+.
      def initialize(tree, doc)
        @tree, @doc = tree, doc
        @footnote_counter = 0
      end

      # Convert the element +tree+ of the Kramdown document +doc+ to HTML.
      def self.convert(tree, doc)
        self.new(tree, doc).convert
      end

      # Convert the element tree +el+, setting the indentation level to +indent+.
      def convert(el = @tree, indent = -2)
        result = ''
        el.children.each do |inner_el|
          result += convert(inner_el, indent + 2)
        end
        convert_element(el, result, indent)
      end

      # Convert the element +el+. The result of the already converted inner elements is stored in
      # +inner+ and the current indentation level in +indent+.
      def convert_element(el, inner, indent)
        case el.type
        when :blank
          "\n"
        when :text
          escape_html(el.value, false)
        when :p
          ' '*indent + '<p' + options_for_element(el) + '>' + inner + "</p>\n"
        when :codeblock
          ' '*indent + '<pre' + options_for_element(el) + '><code>' + escape_html(el.value) + (el.value =~ /\n\Z/ ? '' : "\n") + "</code></pre>\n"
        when :blockquote
          ' '*indent + '<blockquote' + options_for_element(el) + ">\n" + inner + ' '*indent + "</blockquote>\n"
        when :header
          ' '*indent + '<h' + el.options[:level].to_s + options_for_element(el) + '>' +
            inner + "</h" + el.options[:level].to_s + ">\n"
        when :hr
          ' '*indent + "<hr />\n"
        when :ul, :ol
          ' '*indent + "<#{el.type}" + options_for_element(el) + ">\n" + inner + ' '*indent + "</#{el.type}>\n"
        when :li
          output = ' '*indent + "<li" + options_for_element(el) + ">"
          if el.options[:first_as_block]
            output += "\n" + inner + ' '*indent
          else
            output += inner + (inner =~ /\n\Z/ ? ' '*indent : '')
          end
          output + "</li>\n"
        when :em, :strong
          "<#{el.type}" + options_for_element(el) + '>' + inner + "</#{el.type}>"
        when :a
          "<a" + options_for_element(el) + '>' + inner + "</a>"
        when :img
          "<img" + options_for_element(el) + " />"
        when :codespan
          "<code" + options_for_element(el) + '>' + escape_html(el.value) + "</code>"
        when :html_inline
          el.value
        when :html_block
          el.value + "\n"
        when :html_raw
          el.value + (el.options[:type] == :block ? "\n" : '')
        when :html_element
          if @doc.options[:filter_html].include?(el.value)
            inner + (el.options[:type] == :block ? "\n" : '')
          elsif el.options[:type] == :inline || el.options[:type] == :unknown
            "<#{el.value}#{options_for_element(el)}" + (!inner.empty? ? ">#{inner}</#{el.value}>" : " />")
          else
            ' '*indent + "<#{el.value}#{options_for_element(el)}" + (!inner.empty? ? ">#{inner}" + ' '*indent + "</#{el.value}>" : " />") + "\n"
          end
        when :html_text
          el.value
        when :br
          "<br />"
        when :footnote
          "<sup id=\"fnref:#{el.options[:name]}\"><a href=\"#fn:#{el.options[:name]}\" rel=\"footnote\">#{@doc.options[:footnotes][el.options[:name]][:number]}</a></sup>"
        when :eob
          ''
        when :root
          inner.chomp("\n") + add_footnote_content
        else
          raise "Conversion of element #{el.type} not implemented"
        end
      end

      # Return a HTML list with the footnote content for the used footnotes.
      def add_footnote_content
        ol = Element.new(:ol)
        @doc.options[:footnotes].select {|k,v| k.kind_of?(String) && v[:number]}.
          sort {|(ak,av),(bk,bv)| av[:number] <=> bv[:number]}.each do |name, data|
          li = Element.new(:li, nil, {:attr => {:id => "fn:#{name}"}, :first_as_block => true})
          li.children = data[:content].children
          ol.children << li

          ref = Element.new(:html_inline, "<a href=\"#fnref:#{name}\" rev=\"footnote\">&#8617;</a>")
          if li.children.last.type == :p
            para = li.children.last
          else
            li.children << (para = Element.new(:p))
          end
          para.children << ref
        end
        (ol.children.empty? ? '' : "\n<div class=\"footnotes\">\n" + convert(ol, 2) + "</div>\n")
      end

      # Return the string with the attributes of the element +el+.
      def options_for_element(el)
        opts = (el.options[:attr] || {})
        opts = opts.merge(ial_to_options(el.options[:ial])) if el.options[:ial]
        opts.map {|k,v| v.nil? ? '' : " #{k}=\"#{escape_html(v, false)}\"" }.sort.join('')
      end

      # Return a hash with the HTML attributes of the inline attribute list.
      def ial_to_options(ial)
        ial = ial.dup
        (ial.delete(:refs) || []).each do |ref|
          if ref_ial = @doc.options[:alds][ref]
            ref_opts = ial_to_options(ref_ial)
            ial['class'] = ((ial['class'] || '') + " #{ref_opts.delete('class')}").lstrip if ref_opts['class']
            ial.merge!(ref_opts)
          end
        end
        ial
      end

      ENTITY = /\&([\w\d]+|\#x?[\w\d]+);/
      ESCAPE_MAP = {
        '<' => '&lt;',
        '>' => '&gt;',
        '"' => '&quot;',
        '&' => '&amp;'
      }
      ESCAPE_ALL_RE = Regexp.union(*ESCAPE_MAP.collect {|k,v| Regexp.escape(k)})
      ESCAPE_ALL_NOT_ENTITIES_RE = Regexp.union(ENTITY, ESCAPE_ALL_RE)

      # Escape the special HTML characters in the string +str+. If +all+ is +true+ then all
      # characters are escaped, if +all+ is +false+
      def escape_html(str, all = true)
        str.gsub(all ? ESCAPE_ALL_RE : ESCAPE_ALL_NOT_ENTITIES_RE) {|m| ESCAPE_MAP[m] || m}
      end

    end

  end
end
