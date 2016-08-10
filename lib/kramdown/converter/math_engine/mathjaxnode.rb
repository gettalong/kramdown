# -*- coding: utf-8 -*-
#
#--
# Copyright (C) 2009-2016 Thomas Leitner <t_leitner@gmx.at>
#
# This file is part of kramdown which is licensed under the MIT.
#++
#

module Kramdown::Converter::MathEngine

  # Uses the mathjax-node library for converting math formulas to MathML.
  module MathjaxNode
    VALID_FORMATS = %w(svg mml)

    # MathjaxNode is available if this constant is +true+.
    AVAILABLE = RUBY_VERSION >= '1.9' && begin
      %x{node --version}[1..-2] >= '4.0'
    rescue
      begin
        %x{nodejs --version}[1..-2] >= '4.0'
      rescue
        false
      end
    end && begin
      npm = %x{npm --global --depth=1 list mathjax-node 2>&1}

      unless /mathjax-node@/ === npm.lines.drop(1).join("\n")
        npm = %x{npm --depth=1 list mathjax-node 2>&1}
      end

      MML_BIN = File.join(npm.lines.first.strip, "node_modules/mathjax-node/bin/tex2mml")
      SVG_BIN = File.join(npm.lines.first.strip, "node_modules/mathjax-node/bin/tex2svg")

      /mathjax-node@/ === npm.lines.drop(1).join("\n") && File.exist?(MML_BIN) && File.exist?(SVG_BIN)
    rescue
      false
    end

    def self.call(converter, el, opts)
      type = el.options[:category]

      format = converter.options[:math_engine_opts][:format].to_s
      format = VALID_FORMATS.include?(format) ? format : 'mml'

      cmd = []
      cmd << const_get("#{format.upcase}_BIN")
      cmd << "--inline" unless type == :block

      if format == 'mml'
        cmd << "--semantics" if converter.options[:math_engine_opts][:semantics] == true
        cmd << "--notexhints" if converter.options[:math_engine_opts][:texhints] == false
      end

      result = IO.popen(cmd << el.value).read.strip

      if format == 'mml'
        attr = el.attr.dup
        attr.delete('xmlns')
        attr.delete('display')
        result.insert("<math".length, converter.html_attributes(attr))
      end

      if format == 'svg'
        if type == :block
          result.insert(0, '<p>')
          result.insert(result.length, '</p>')
          result.insert('<p'.length, converter.html_attributes(el.attr.dup))
        end
      end

      (type == :block ? "#{' '*opts[:indent]}#{result}\n" : result)
    end
  end

end
