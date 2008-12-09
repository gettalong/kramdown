module Kramdown

  module Converter

    class ToHtml

      def initialize(tree, doc)
        @tree, @doc = tree, doc
      end

      def self.convert(tree, doc)
        self.new(tree, doc).convert
      end

      def convert(el = @tree, indent = -2)
        result = ''
        el.children.each do |inner_el|
          result += convert(inner_el, indent + 2)
        end
        convert_element(el, result, indent)
      end

      def convert_element(el, inner, indent)
        case el.type
        when :white
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
          if el.options[:first_as_para]
            output += "\n" + inner + ' '*indent
          elsif el.children.length > 1
            output += inner + ' '*indent
          else
            output += inner
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
        when :root
          inner.chomp("\n")
        when :html_inline
          el.value
        when :html_block
          el.value + "\n"
        when :br
          "<br />"
        when :eob
          ''
        else
          raise "Conversion of element #{el.type} not implemented"
        end
      end

      def options_for_element(el)
        if el.options[:attr]
          el.options[:attr].map {|k,v| v.nil? ? '' : " #{k}=\"#{escape_html(v, false)}\"" }.sort.join('')
        else
          ''
        end
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

      def escape_html(attr, all = true)
        attr.gsub(all ? ESCAPE_ALL_RE : ESCAPE_ALL_NOT_ENTITIES_RE) {|m| ESCAPE_MAP[m] || m}
      end

    end

  end
end
