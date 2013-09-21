# -*- coding: utf-8 -*-
#
#--
# Copyright (C) 2009-2013 Thomas Leitner <t_leitner@gmx.at>
#
# This file is part of kramdown which is licensed under the MIT.
#++
#

require 'prawn'
require 'kramdown/utils/entities'

module Kramdown

  module Converter

    # Converts an element tree to a PDF using the prawn PDF library.
    #
    # This basic version provides a nice starting point for customizations but can also be used
    # directly.
    #
    # There can be the following two methods for each element type: render_TYPE(el, opts) and
    # TYPE_options(el, opts) where +el+ is a kramdown element and +opts+ an hash with rendering
    # options.
    #
    # The render_TYPE(el, opts) is used for rendering the specific element. If the element is a span
    # element, it should return a hash or an array of hashes that can be used by the #formatted_text
    # method of Prawn::Document. This method can then be used in block elements to actually render
    # the span elements.
    #
    # The rendering options are passed from the parent to its child elements. This allows one to
    # define general options at the top of the tree (the root element) that can later be changed or
    # amended.
    #
    #
    # Currently supports the conversion of all elements except those of the following types:
    #
    #   :html_element, :img, :footnote
    #
    #
    class Pdf < Base

      include Prawn::Measurements

      def initialize(root, options)
        super
        @stack = []
        @dests = {}
      end

      # PDF templates are applied before conversion. They should contain code to augment the
      # converter object (i.e. to override the methods).
      def apply_template_before?
        true
      end

      # Returns +false+.
      def apply_template_after?
        false
      end

      DISPATCHER_RENDER = Hash.new {|h,k| h[k] = "render_#{k}"} #:nodoc:
      DISPATCHER_OPTIONS = Hash.new {|h,k| h[k] = "#{k}_options"} #:nodoc:

      # Invoke the special rendering method for the given element +el+.
      #
      # A PDF destination is also added at the current location if th element has an ID or if the
      # element is of type :header and the :auto_ids option is set.
      def convert(el, opts = {})
        id = el.attr['id']
        id = generate_id(el.options[:raw_text]) if !id && @options[:auto_ids] && el.type == :header
        if !id.to_s.empty? && !@dests.has_key?(id)
          @pdf.add_dest(id, @pdf.dest_xyz(0, @pdf.y))
          @dests[id] = @pdf.dest_xyz(0, @pdf.y)
        end
        send(DISPATCHER_RENDER[el.type], el, opts)
      end

      protected

      # Render the children of this element with the given options and return the results as array.
      #
      # Each time a child is rendered, the +TYPE_options+ method is invoked (if it exists) to get
      # the specific options for the element with which the given options are updated.
      def inner(el, opts)
        @stack.push([el, opts])
        result = el.children.map do |inner_el|
          options = opts.dup
          if respond_to?(DISPATCHER_OPTIONS[inner_el.type], true)
            options.update(send(DISPATCHER_OPTIONS[inner_el.type], inner_el, options))
          end
          convert(inner_el, options)
        end.flatten.compact
        @stack.pop
        result
      end


      # ----------------------------
      # :section: Element rendering methods
      # ----------------------------


      def root_options(root, opts)
        {:font => 'Times-Roman', :size => 12, :leading => 2}
      end

      def render_root(root, opts)
        @pdf = setup_document(root)
        inner(root, root_options(root, opts))
        create_outline(root)
        finish_document(root)
        @pdf.render
      end

      def header_options(el, opts)
        size = opts[:size] * 1.15**(6 - el.options[:level])
        {
          :font => "Helvetica", :styles => (opts[:styles] || []) + [:bold],
          :size => size, :bottom_padding => opts[:size], :top_padding => opts[:size]
        }
      end

      def p_options(el, opts)
        bpad = (el.options[:transparent] ? opts[:leading] : opts[:size])
        {:align => :justify, :bottom_padding => bpad}
      end

      def render_header(el, opts)
        render_padded_and_formatted_text(el, opts)
      end
      alias_method :render_p, :render_header

      def render_blockquote(el, opts)
        @pdf.indent(mm2pt(10), mm2pt(10)) { inner(el, opts) }
      end

      def ul_options(el, opts)
        {:bottom_padding => opts[:size]}
      end

      def render_ul(el, opts)
        with_block_padding(el, opts) do
          el.children.each do |li|
            @pdf.float { @pdf.formatted_text([text_hash("•", opts)]) }
            @pdf.indent(mm2pt(6)) { convert(li, opts) }
          end
        end
      end

      def ol_options(el, opts)
        {:bottom_padding => opts[:size]}
      end

      def render_ol(el, opts)
        with_block_padding(el, opts) do
          el.children.each_with_index do |li, index|
            @pdf.float { @pdf.formatted_text([text_hash("#{index+1}.", opts)]) }
            @pdf.indent(mm2pt(6)) { convert(li, opts) }
          end
        end
      end

      def render_li(el, opts)
        inner(el, opts)
      end

      def render_dl(el, opts)
        inner(el, opts)
      end

      def dt_options(el, opts)
        {:styles => (opts[:styles] || []) + [:bold], :bottom_padding => 0}
      end

      def render_dt(el, opts)
        render_padded_and_formatted_text(el, opts)
      end

      def render_dd(el, opts)
        @pdf.indent(mm2pt(10)) { inner(el, opts) }
      end

      def render_math(el, opts)
        if el.options[:category] == :block
          @pdf.formatted_text([{:text => el.value}], block_hash(el, opts))
        else
          {:text => el.value}
        end
      end

      def hr_options(el, opts)
        {:top_padding => opts[:size], :bottom_padding => opts[:size]}
      end

      def render_hr(el, opts)
        with_block_padding(el, opts) do
          @pdf.stroke_horizontal_line(@pdf.bounds.left + mm2pt(5), @pdf.bounds.right - mm2pt(5))
        end
      end

      def codeblock_options(el, opts)
        {
          :font => 'Courier', :color => '880000',
          :top_padding => opts[:size], :bottom_padding => opts[:size]
        }
      end

      def render_codeblock(el, opts)
        with_block_padding(el, opts) do
          @pdf.formatted_text([text_hash(el.value, opts, false)], block_hash(opts))
        end
      end

      def table_options(el, opts)
        {:top_padding => opts[:size], :bottom_padding => opts[:size]}
      end

      def render_table(el, opts)
        data = []
        el.children.each do |container|
          container.children.each do |row|
            data << []
            row.children.each do |cell|
              if cell.children.any? {|child| child.options[:category] == :block}
                warning("Can't render tables with cells containing block elements")
                return
              end
              cell_data = inner(cell, opts)
              data.last << cell_data.map {|c| c[:text]}.join('')
            end
          end
        end
        with_block_padding(el, opts) do
          @pdf.table(data, :width => @pdf.bounds.right) do
            el.options[:alignment].each_with_index do |alignment, index|
              columns(index).align = alignment unless alignment == :default
            end
          end
        end
      end



      def render_text(el, opts)
        text_hash(el.value.to_s, opts)
      end

      def em_options(el, opts)
        {:styles => (opts[:styles] || []) << :italic}
      end

      def strong_options(el, opts)
        {:styles => (opts[:styles] || []) + [:bold]}
      end

      def a_options(el, opts)
        hash = {:color => '000088'}
        if el.attr['href'].start_with?('#')
          hash[:anchor] = el.attr['href'].sub(/\A#/, '')
        else
          hash[:link] = el.attr['href']
        end
        hash
      end

      def render_em(el, opts)
        inner(el, opts)
      end
      alias_method :render_strong, :render_em
      alias_method :render_a, :render_em

      def codespan_options(el, opts)
        {:font => 'Courier', :color => '880000'}
      end

      def render_codespan(el, opts)
        text_hash(el.value, opts)
      end

      def render_br(el, opts)
        text_hash("\n", opts, false)
      end

      def render_smart_quote(el, opts)
        text_hash(smart_quote_entity(el).char, opts)
      end

      def render_typographic_sym(el, opts)
        str = if el.value == :laquo_space
                ::Kramdown::Utils::Entities.entity('laquo').char +
                  ::Kramdown::Utils::Entities.entity('nbsp').char
              elsif el.value == :raquo_space
                ::Kramdown::Utils::Entities.entity('raquo').char +
                  ::Kramdown::Utils::Entities.entity('nbsp').char
              else
                ::Kramdown::Utils::Entities.entity(el.value.to_s).char
              end
        text_hash(str, opts)
      end

      def render_entity(el, opts)
        text_hash(el.value.char, opts)
      end

      def render_abbreviation(el, opts)
        text_hash(el.value, opts)
      end



      def render_xml_comment(el, opts) #:nodoc:
        # noop
      end
      alias_method :render_xml_pi, :render_xml_comment
      alias_method :render_comment, :render_xml_comment
      alias_method :render_blank, :render_xml_comment

      def render_img(el, *args) #:nodoc:
        warning("Rendering #{el.type} not supported for PDF converter")
        nil
      end
      alias_method :render_footnote, :render_img
      alias_method :render_raw, :render_img
      alias_method :render_html_element, :render_img


      # ----------------------------
      # :section: Organizational methods
      #
      # These methods are used, for example, to up the needed Prawn::Document instance or to create
      # a PDF outline.
      # ----------------------------


      # Return a hash with options that are suitable for Prawn::Document.new.
      #
      # Used in #setup_document.
      def document_options(root)
        {
          :page_size => 'A4', :page_layout => :portrait, :margin => mm2pt(20),
          :info => {
            :Creator => 'kramdown PDF converter',
            :CreationDate => Time.now
          },
          :compress => true, :optimize_objects => true
        }
      end

      # Create a Prawn::Document object and return it.
      #
      # Can be used to define repeatable content or register fonts.
      #
      # Used in #render_root.
      def setup_document(root)
        Prawn::Document.new(document_options(root))
      end

      #
      #
      # Used in #render_root.
      def finish_document(root)
        # no op
      end

      # Create the PDF outline from the header elements in the TOC.
      def create_outline(root)
        patch_outline_object
        toc = ::Kramdown::Converter::Toc.convert(root).first

        text_of_header = lambda do |el|
          if el.type == :text
            el.value
          else
            el.children.map {|c| text_of_header.call(c)}.join('')
          end
        end

        add_section = lambda do |item, parent|
          text = text_of_header.call(item.value)
          destination = @dests[item.attr[:id]]
          if !parent
            @pdf.outline.page(:title => text, :destination => destination)
          else
            @pdf.outline.add_subsection_to(parent) do
              @pdf.outline.page(:title => text, :destination => destination)
            end
          end
          item.children.each {|c| add_section.call(c, text)}
        end

        toc.children.each do |item|
          add_section.call(item, nil)
        end
      end

      # Patch the pdf_document.outline object to accept arbitrary destinations.
      def patch_outline_object
        def (@pdf.outline).create_outline_item(title, options)
          outline_item = ::Prawn::OutlineItem.new(title, parent, options)

          case options[:destination]
          when Integer
            page_index = options[:destination] - 1
            outline_item.dest = [document.state.pages[page_index].dictionary, :Fit]
          when Array
            outline_item.dest = options[:destination]
          end

          outline_item.prev = prev if @prev
          items[title] = document.ref!(outline_item)
        end
      end


      # ----------------------------
      # :section: Helper methods
      # ----------------------------


      # Move the prawn document cursor down before and/or after yielding the given block.
      #
      # The :top_padding and :bottom_padding options are used for determinig the padding amount.
      def with_block_padding(el, opts)
        @pdf.move_down(opts[:top_padding]) if opts.has_key?(:top_padding)
        yield
        @pdf.move_down(opts[:bottom_padding]) if opts.has_key?(:bottom_padding)
      end

      # Render the children of the given element as formatted text and respect the top/bottom
      # padding (see #with_block_padding).
      def render_padded_and_formatted_text(el, opts)
        with_block_padding(el, opts) { @pdf.formatted_text(inner(el, opts), block_hash(opts)) }
      end

      # Helper function that returns a hash with valid "formatted text" options.
      #
      # The +text+ parameter is used as value for the :text key and if +squeeze_whitespace+ is
      # +true+, all whitespace is converted into spaces.
      def text_hash(text, opts, squeeze_whitespace = true)
        text = text.gsub(/\s+/, ' ') if squeeze_whitespace
        hash = {:text => text}
        [:styles, :size, :character_spacing, :font, :color, :link,
         :anchor, :draw_text_callback, :callback].each do |key|
          hash[key] = opts[key] if opts.has_key?(key)
        end
        hash
      end

      # Helper function that returns a hash with valid options for the prawn #text_box extracted
      # from the given options.
      def block_hash(opts)
        hash = {}
        [:align, :valign, :mode, :final_gap, :leading, :fallback_fonts,
         :direction, :indent_paragraphs].each do |key|
          hash[key] = opts[key] if opts.has_key?(key)
        end
        hash
      end

    end

  end
end
