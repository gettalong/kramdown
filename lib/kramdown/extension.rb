# -*- coding: utf-8 -*-

module Kramdown

  class Extension

    def parse_comment(tree, opts, body)
      nil
    end

    def parse_nokramdown(tree, opts, body)
      tree.children << Element.new(:raw, body)
    end

  end

end


