# -*- coding: utf-8 -*-
#
#--
# Copyright (C) 2009-2010 Thomas Leitner <t_leitner@gmx.at>
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

require 'kramdown/compatibility'

require 'kramdown/version'
require 'kramdown/element'
require 'kramdown/error'
require 'kramdown/parser'
require 'kramdown/converter'
require 'kramdown/options'
require 'kramdown/utils'

module Kramdown

  # Return the data directory for kramdown.
  def self.data_dir
    unless defined?(@@data_dir)
      require 'rbconfig'
      @@data_dir = File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'data', 'kramdown'))
      @@data_dir = File.expand_path(File.join(Config::CONFIG["datadir"], "kramdown")) if !File.exists?(@@data_dir)
      raise "kramdown data directory not found! This is a bug, please report it!" unless File.directory?(@@data_dir)
    end
    @@data_dir
  end


  # The main interface to kramdown.
  #
  # This class provides a one-stop-shop for using kramdown to convert text into various output
  # formats. Use it like this:
  #
  #   require 'kramdown'
  #   doc = Kramdown::Document.new('This *is* some kramdown text')
  #   puts doc.to_html
  #
  # The #to_html method is a shortcut for using the Converter::Html class. See #method_missing for
  # more information.
  #
  # The second argument to the ::new method is an options hash for customizing the behaviour of the
  # used parser and the converter. See ::new for more information!
  class Document

    # The root Element of the element tree. It is immediately available after the ::new method has
    # been called.
    attr_accessor :root

    # The options hash which holds the options for parsing/converting the Kramdown document.
    attr_reader :options

    # An array of warning messages. It is filled with warnings during the parsing phase (i.e. in
    # ::new) and the conversion phase.
    attr_reader :warnings


    # Create a new Kramdown document from the string +source+ and use the provided +options+. The
    # options that can be used are defined in the Options module.
    #
    # The special options key :input can be used to select the parser that should parse the
    # +source+. It has to be the name of a class in the Kramdown::Parser module. For example, to
    # select the kramdown parser, one would set the :input key to +Kramdown+. If this key is not
    # set, it defaults to +Kramdown+.
    #
    # The +source+ is immediately parsed by the selected parser so that the root element is
    # immediately available and the output can be generated.
    def initialize(source, options = {})
      @options = Options.merge(options).freeze
      parser = (options[:input] || 'kramdown').to_s
      parser = parser[0..0].upcase + parser[1..-1]
      if Parser.const_defined?(parser)
        @root, @warnings = Parser.const_get(parser).parse(source, @options)
      else
        raise Kramdown::Error.new("kramdown has no parser to handle the specified input format: #{options[:input]}")
      end
    end

    # Check if a method is invoked that begins with +to_+ and if so, try to instantiate a converter
    # class (i.e. a class in the Kramdown::Converter module) and use it for converting the document.
    #
    # For example, +to_html+ would instantiate the Kramdown::Converter::Html class.
    def method_missing(id, *attr, &block)
      if id.to_s =~ /^to_(\w+)$/ && (name = method_to_class_name($1)) && Converter.const_defined?(name)
        output, warnings = Converter.const_get(name).convert(@root, @options)
        @warnings.concat(warnings)
        output
      else
        super
      end
    end

    def inspect #:nodoc:
      "<KD:Document: options=#{@options.inspect} root=#{@root.inspect} warnings=#{@warnings.inspect}>"
    end

    private
    def method_to_class_name(name)
      name.split('_').inject(''){ |s,x| s << x[0..0].upcase + x[1..-1] }
    end

  end

end

