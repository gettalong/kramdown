# -*- coding: utf-8 -*-
#
#--
# Copyright (C) 2009 Thomas Leitner <t_leitner@gmx.at>
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

    # This class servers as base class for all converters.
    class Base

      # Initialize the converter with the given Kramdown document +doc+.
      def initialize(doc)
        @doc = doc
        @doc.conversion_infos.clear
      end
      private_class_method(:new, :allocate)

      # Convert the Kramdown document +doc+ to the output format implemented by a subclass.
      #
      # Initializes a new instance of the calling class and then calls the #convert method that must
      # be implemented by each subclass. If the +template+ option is specified and non-empty, the
      # result is rendered into the specified template.
      def self.convert(doc)
        result = new(doc).convert(doc.tree)
        result = apply_template(doc, result) if !doc.options[:template].empty?
        result
      end

      # Apply the template specified in the +doc+ options, using +body+ as the body string.
      def self.apply_template(doc, body)
        erb = ERB.new(get_template(doc.options[:template]))
        erb.result(binding)
      end

      # Return the template specified by +template+.
      def self.get_template(template)
        format_ext = '.' + self.name.split(/::/).last.downcase
        shipped = File.join(Kramdown.data_dir, template + format_ext)
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

    end

  end

end
