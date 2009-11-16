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
  # [+tree+]
  #    An instance of Element representing the parent element under which the extension was found.
  # [+opts+]
  #    A hash containing the options set in the extension.
  # [+body+]
  #    A string containing the body of the extension. If no body is available, this is +nil+.
  class Extension

    # Some extensions need the current document +doc+, so this needs to be set on creation.
    def initialize(doc)
      @doc = doc
    end

    # Just ignore everything and do nothing.
    def parse_comment(tree, opts, body)
      nil
    end

    # Add the body (if available) as <tt>:raw</tt> Element to the +tree+.
    def parse_nokramdown(tree, opts, body)
      tree.children << Element.new(:raw, body) if body.kind_of?(String)
    end

    # Update the document options with the options set in +opts+.
    def parse_kdoptions(tree, opts, body)
      if opts['auto_ids'].downcase.strip == 'false'
        @doc.options[:auto_ids] = false
      else
        @doc.options[:auto_ids] = true
      end
    end

  end

end


