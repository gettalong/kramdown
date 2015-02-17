require 'rexml/parsers/baseparser'

module Kramdown::Converter::SyntaxHighlighter
  module Pygments
    begin
      require 'pygments'

      # Highlighting via pygments is available if this constant is +true+.
      AVAILABLE = true
    rescue LoadError
      AVAILABLE = false  # :nodoc:
    end

    extend ::Kramdown::Utils::Html

    DEFAULTS = {
      :startinline => true,
      :encoding => 'utf-8',
      :nowrap => true
    }.freeze

    def self.call(converter, text, lang, type, _unused_opts)
      opts = DEFAULTS.merge(converter.options[:syntax_highlighter_opts])
      lexer = lang || opts[:default_lang]
      return nil unless lexer

      code = ::Pygments.highlight(text, :lexer => lexer, :options => opts)

      attrs = {
        "class" => "language-#{lexer.gsub('+', '-')}",
        "data-lang" => lexer
      }

      "<pre><code#{html_attributes(attrs)}>#{code.chomp}</code></pre>"
    end
  end
end
