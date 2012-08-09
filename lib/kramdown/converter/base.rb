# -*- coding: utf-8 -*-
#
#--
# Copyright (C) 2009-2012 Thomas Leitner <t_leitner@gmx.at>
#
# This file is part of kramdown.
#
# kramdown is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#++
#

require 'erb'

module Kramdown

  module Converter

    # == \Base class for converters
    #
    # This class serves as base class for all converters. It provides methods that can/should be
    # used by all converters (like #generate_id) as well as common functionality that is
    # automatically applied to the result (for example, embedding the output into a template).
    #
    # A converter object is used as a throw-away object, i.e. it is only used for storing the needed
    # state information during conversion. Therefore one can't instantiate a converter object
    # directly but only use the Base::convert method.
    #
    # == Implementing a converter
    #
    # Implementing a new converter is rather easy: just derive a new class from this class and put
    # it in the Kramdown::Converter module (the latter is only needed if auto-detection should work
    # properly). Then you need to implement the #convert method which has to contain the conversion
    # code for converting an element and has to return the conversion result.
    #
    # The actual transformation of the document tree can be done in any way. However, writing one
    # method per element type is a straight forward way to do it - this is how the Html and Latex
    # converters do the transformation.
    #
    # Have a look at the Base::convert method for additional information!
    class Base

      # Can be used by a converter for storing arbitrary information during the conversion process.
      attr_reader :data

      # The hash with the conversion options.
      attr_reader :options

      # The root element that is converted.
      attr_reader :root

      # The warnings array.
      attr_reader :warnings

      # Initialize the converter with the given +root+ element and +options+ hash.
      def initialize(root, options)
        @options = options
        @root = root
        @data = {}
        @warnings = []
      end
      private_class_method(:new, :allocate)

      # Convert the element tree +tree+ and return the resulting conversion object (normally a
      # string) and an array with warning messages. The parameter +options+ specifies the conversion
      # options that should be used.
      #
      # Initializes a new instance of the calling class and then calls the #convert method with
      # +tree+ as parameter. If the +template+ option is specified and non-empty, the result is
      # rendered into the specified template. The template resolution is done in the following way:
      #
      # 1. Look in the current working directory for the template.
      #
      # 2. Append +.convertername+ (e.g. +.html+) to the template name and look for the resulting
      #    file in the current working directory.
      #
      # 3. Append +.convertername+ to the template name and look for it in the kramdown data
      #    directory.
      def self.convert(tree, options = {})
        converter = new(tree, ::Kramdown::Options.merge(options.merge(tree.options[:options] || {})))
        result = converter.convert(tree)
        result = apply_template(converter, result) if !converter.options[:template].empty?
        [result, converter.warnings]
      end

      # Convert the element +el+ and return the resulting object.
      #
      # This is the only method that has to be implemented by sub-classes!
      def convert(el)
        raise NotImplementedError
      end

      # Apply the +template+ using +body+ as the body string.
      def self.apply_template(converter, body) # :nodoc:
        erb = ERB.new(get_template(converter.options[:template]))
        obj = Object.new
        obj.instance_variable_set(:@converter, converter)
        obj.instance_variable_set(:@body, body)
        erb.result(obj.instance_eval{binding})
      end

      # Return the template specified by +template+.
      def self.get_template(template) # :nodoc:
        format_ext = '.' + self.name.split(/::/).last.downcase
        shipped = File.join(::Kramdown.data_dir, template + format_ext)
        if File.exist?(template)
          File.read(template)
        elsif File.exist?(template + format_ext)
          File.read(template + format_ext)
        elsif File.exist?(shipped)
          File.read(shipped)
        else
          raise "The specified template file #{template} does not exist"
        end
      end

      # Add the given warning +text+ to the warning array.
      def warning(text)
        @warnings << text
      end

      # Return +true+ if the header element +el+ should be used for the table of contents (as
      # specified by the +toc_levels+ option).
      def in_toc?(el)
        @options[:toc_levels].include?(el.options[:level])
      end

      # Return the output header level given a level.
      #
      # Uses the +header_offset+ option for adjusting the header level.
      def output_header_level(level)
        [[level + @options[:header_offset], 6].min, 1].max
      end

      # Generate an unique alpha-numeric ID from the the string +str+ for use as a header ID.
      #
      # Uses the option +auto_id_prefix+: the value of this option is prepended to every generated
      # ID.
      def generate_id(str)
        gen_id = str.gsub(/^[^a-zA-Z]+/, '')
        gen_id.tr!('^a-zA-Z0-9 -', '')
        gen_id.tr!(' ', '-')
        gen_id.downcase!
        gen_id = 'section' if gen_id.length == 0
        @used_ids ||= {}
        if @used_ids.has_key?(gen_id)
          gen_id += '-' << (@used_ids[gen_id] += 1).to_s
        else
          @used_ids[gen_id] = 0
        end
        @options[:auto_id_prefix] + gen_id
      end

      SMART_QUOTE_INDICES = {:lsquo => 0, :rsquo => 1, :ldquo => 2, :rdquo => 3} # :nodoc:

      # Return the entity that represents the given smart_quote element.
      def smart_quote_entity(el)
        res = @options[:smart_quotes][SMART_QUOTE_INDICES[el.value]]
        ::Kramdown::Utils::Entities.entity(res)
      end

    end

  end

end
