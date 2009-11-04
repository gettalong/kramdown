require 'kramdown/parser'

module Kramdown
  module Parser

    class Registry

      Data = Struct.new(:name, :type, :start_re, :module, :method)

      @@parsers = {}

      def self.define_parser(type, name, start_re, mod_name, meth_name = "parse_#{name}")
        raise "A parser with the name #{name} already exists!" if @@parsers.has_key?(name)
        @@parsers[name] = Data.new(name, type, start_re, mod_name, meth_name)
      end

      def self.parser(name = nil)
        @@parsers[name]
      end

      def self.has_parser?(name, type = nil)
        @@parsers[name] && (type.nil? || @@parsers[name].type == type)
      end

      def self.parsers
        @@parsers
      end
    end

  end
end
