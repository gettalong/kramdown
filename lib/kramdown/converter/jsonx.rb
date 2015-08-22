# -*- coding: utf-8 -*-
#
#--
# Copyright (C) 2009-2015 Thomas Leitner <t_leitner@gmx.at>
#
# This file is part of kramdown which is licensed under the MIT.
#++
#

require 'kramdown/parser'
require 'kramdown/converter'
require 'kramdown/utils'
require 'json'

module Kramdown

  module Converter

    # Converts a Kramdown::Document to JSON.
    #
    # I am calling the class "Jsonx" rather than "Json"
    # to force the use of a "to_jsonx" method to convert
    # documents to JSON. Using the more natural "Json"
    # causes problems between our custom "to_json" and 
    # Ruby's native "to_json"
    class Jsonx < Base

      def initialize(root, options)
        super
        @pretty_print = @options[:pretty_print] || false
      end

      def convert(el)
        tree = get_tree(el)
        @pretty_print ? JSON.pretty_generate(tree) : JSON.generate(tree)
      end

      def get_tree(el)
        hash = {type: el.type}
        hash[:attr] = el.attr unless el.attr.empty?
        hash[:value] = el.value unless el.value.nil?
        unless el.children.empty?
          hash[:children] = []
          el.children.each {|child| hash[:children] << get_tree(child)}
        end
        hash
      end

    end

  end
end
