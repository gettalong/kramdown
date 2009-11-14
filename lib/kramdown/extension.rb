# -*- coding: utf-8 -*-

module Kramdown

  class Extension

    def initialize(doc)
      @doc = doc
    end

    def parse_comment(tree, opts, body)
      nil
    end

    def parse_nokramdown(tree, opts, body)
      tree.children << Element.new(:raw, body) if body.kind_of?(String)
    end

    def parse_kdoptions(tree, opts, body)
      if opts['auto_ids'].downcase.strip == 'false'
        @doc.options[:auto_ids] = false
      else
        @doc.options[:auto_ids] = true
      end
    end

  end

end


