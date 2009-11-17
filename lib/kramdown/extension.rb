# -*- coding: utf-8 -*-

module Kramdown

  # The base extension class.
  #
  # This class provides implementations for the default extensions defined in the kramdown
  # specification.
  #
  # An extension is a method called <tt>parse_EXTNAME</tt> where +EXTNAME+ is the extension name.
  # These methods are called with three parameters:
  #
  # [+parser+]
  #    The parser instance from which the extension method is called.
  # [+opts+]
  #    A hash containing the options set in the extension.
  # [+body+]
  #    A string containing the body of the extension. If no body is available, this is +nil+.
  class Extension

    # Just ignore everything and do nothing.
    def parse_comment(parser, opts, body)
      nil
    end

    # Add the body (if available) as <tt>:raw</tt> Element to the +parser.tree+.
    def parse_nokramdown(parser, opts, body)
      parser.tree.children << Element.new(:raw, body) if body.kind_of?(String)
    end

    # Update the document options with the options set in +opts+.
    def parse_kdoptions(parser, opts, body)
      if val = opts.delete('auto_ids')
        if val.downcase.strip == 'false'
          parser.doc.options[:auto_ids] = false
        elsif !val.empty?
          parser.doc.options[:auto_ids] = true
        end
      end
      if val = opts.delete('filter_html')
        parser.doc.options[:filter_html] = val.split(/\s+/)
      end
      if val = opts.delete('footnote_nr')
        parser.doc.options[:footnote_nr] = Integer(val) rescue parser.doc.options[:footnote_nr]
      end
      opts.each {|k,v| parser.warning("Unknown kramdown options '#{k}'")}
    end

  end

end


