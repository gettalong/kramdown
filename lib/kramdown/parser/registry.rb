# -*- coding: utf-8 -*-

module Kramdown
  module Parser

    # A small helper class for storing block and span level parser methods by name.
    class Registry

      # Holds all the needed data for one block/span level parser.
      Data = Struct.new(:name, :type, :start_re, :module, :method)

      @@parsers = {}

      # Add a parser method
      #
      # * of type +type+ (can either be <tt>:block</tt> or <tt>:span</tt>),
      # * with the given +name+,
      # * defined in the module +mod_nam+
      # * and using +start_re+ as start
      #
      # to the registry. The method name is automatically derived from the +name+ or can explicitly
      # be set by using the +meth_name+ parameter.
      def self.define_parser(type, name, start_re, mod_name, meth_name = "parse_#{name}")
        raise "A parser with the name #{name} already exists!" if @@parsers.has_key?(name)
        @@parsers[name] = Data.new(name, type, start_re, mod_name, meth_name)
      end

      # Return the Data structure for the parser +name+.
      def self.parser(name = nil)
        @@parsers[name]
      end

      # Return +true+ if the Registry has a parser called +name+ of type +type+ (the usage of the
      # type is optional).
      def self.has_parser?(name, type = nil)
        @@parsers[name] && (type.nil? || @@parsers[name].type == type)
      end

    end

  end
end
