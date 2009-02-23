require 'rexml/parsers/treeparser'
require 'rexml/document'
require 'stringio'

module Kramdown

  class Parser

    module HTMLParser

      class CustomDocument < REXML::Document

        # BEGIN Ruby 1.9 entity fix to allow arbitrary entities
        def doctype
          dt = REXML::DocType.new('test', 'test')
          def dt.entities
            ent = {}
            def ent.has_key?(x)
              true
            end
            ent
          end
          dt
        end if RUBY_VERSION >= '1.9'
        # END

      end

      class CustomBaseParser < REXML::Parsers::BaseParser

        def initialize(*args, &block)
          super
          @tag = nil
          @count = 0
          @finished = false

          # BEGIN The following hack allows arbitrary namespaces to be used in Rexml shipped with Ruby 1.9.1
          @nsstack = []
          x = Object.new
          def x.member?(val); true; end
          @nsstack << x
          # END
        end

        def pull
          throw :finished if @finished
          event = super
          if event[0] == :start_element
            @tag = event[1] if @tag.nil?
            @count += 1 if @tag == event[1]
          elsif event[0] == :end_element && event[1] == @tag
            @count -= 1
            @finished = true if @count == 0
          elsif event[0] == :comment || event[0] == :processing_instruction
            @finished = true
          end
          event
        end

      end

      class CustomTreeParser < REXML::Parsers::TreeParser

        def initialize(source)
          @build_context = CustomDocument.new
          # BEGIN The following hack works around a problem on 1.8 (when supplying a String to
          # BaseParser (or more exactly Source), the position in the string is not calculated
          # correctly)
          source = StringIO.new(source)
          def source.method_missing(id, *args)
            id.to_s =~ /\?$/ ? false : self
          end
          # END
          @parser = CustomBaseParser.new(source)
        end

        def doc
          @build_context
        end

        def pos
          @parser.position
        end

      end

      HTML_PARSE_AS_BLOCK = %w{div blockquote pre table dl ol ul form fieldset}
      HTML_PARSE_AS_SPAN  = %w{a address b dd dt em h1 h2 h3 h4 h5 h6 legend li p span td th}
      HTML_PARSE_AS_RAW   = %w{script math}
      HTML_ALL = HTML_PARSE_AS_RAW + HTML_PARSE_AS_BLOCK + HTML_PARSE_AS_SPAN

      def parse_html(html_type)
        parser = CustomTreeParser.new(@state.src.string[@state.src.pos..-1])
        begin
          catch(:finished) { parser.parse }
          elements = rexml_to_kramdown(parser.doc.children, html_type).children
        rescue
          elements = [Element.new(:html_raw, @state.src.string[@state.src.pos..-1], :type => html_type)]
        end
        @state.tree.children += elements

        @state.src.pos = (parser.pos == 0 ? @state.src.string.length : @state.src.pos + parser.pos)
        @state.src.scan(/\s*?\n/)
      end

      def rexml_to_kramdown(elements, html_type, container = Element.new(:root))
        indent = elements.shift.to_s if container.type == :root && elements.first.node_type == :text
        elements.each do |element|
          if element.node_type == :element
            el = Element.new(:html_element, element.expanded_name, :attr => element.attributes.to_hash, :type => html_type)

            mdattr = el.options[:attr].delete('markdown') if HTML_ALL.include?(el.value)
            parse_as_block = ((@doc.options[:auto_parse_block_html] || mdattr == '1') && HTML_PARSE_AS_BLOCK.include?(el.value)) ||
              mdattr == 'block'

            if parse_as_block
              data = element.children.join('').gsub(/^#{indent}/, '')
              data += "\n" if data !~ /\n\Z/
              sub_parse_blocks(el, data)
            else
              rexml_to_kramdown(element.children, :unknown, el)
            end
          else
            el = if element.node_type == :text
                   Element.new(:html_text, element.to_s)
                 elsif element.node_type == :comment
                   Element.new(:html_raw, "<!--#{element}-->", :type => html_type)
                 else
                   Element.new(:html_raw, element.to_s, :type => html_type)
                 end
          end
          container.children << el
        end
        container
      end

    end

  end

end
