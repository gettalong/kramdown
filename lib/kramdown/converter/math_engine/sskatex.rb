# -*- coding: utf-8 -*-
#
#--
# Copyright (C) 2017 Christian Cornelssen <ccorn@1tein.de>
#
# This file is part of kramdown which is licensed under the MIT.
#++

module Kramdown::Converter::MathEngine

  # Consider this a lightweight alternative to MathjaxNode. Uses KaTeX and ExecJS instead of MathJax
  # and Node.js. Javascript execution context initialization is done only once. As a result, the
  # performance is reasonable.
  module SsKaTeX

    # The original value of <tt>ENV['EXECJS_RUNTIME']</tt>
    ENV_EXECJS_RUNTIME = ENV['EXECJS_RUNTIME']

    # Indicate whether SsKaTeX may be available.
    #
    # This test is incomplete; it cannot test the existence of _katexjs_ nor the availability of a
    # specific _jsrun_ because those depend on configuration not given here. This test mainly
    # indicates whether static dependencies such as the +execjs+ gem are available.
    AVAILABLE = begin
      require 'json'
      ENV['EXECJS_RUNTIME'] = 'Disabled' # Defer automatic JS engine selection
      require 'execjs'
      ExecJS::Runtimes.runtimes.select(&:available?).size > 0
    rescue LoadError
      false
    ensure
      ENV['EXECJS_RUNTIME'] = ENV_EXECJS_RUNTIME
    end
    public_constant :AVAILABLE

    if AVAILABLE

      # Root directory for module-specific data files
      DATADIR = File.join(Kramdown.data_dir, 'sskatex')

      # The default for the +:jsdir+ option in +math_engine_opts+. Path of a directory with
      # Javascript helper files.
      DEFAULT_JSDIR = File.join(DATADIR, 'js')

      # The default path to +katex.js+, cf. the +:katexjs+ option in +math_engine_opts+. For a
      # relative path, the starting point is the current working directory.
      DEFAULT_KATEXJS = File.join('katex', 'katex.min.js')

      # The default for the +:libs+ option in +math_engine_opts+. A list of UTF-8-encoded Javascript
      # helper files to load. Relative paths are interpreted relative to _jsdir_.
      DEFAULT_LIBS = ['escape_nonascii_html.js', 'tex_to_html.js']

      # Class-level cache for JS engine context, queried by configuration. Note: JSCTX contents may
      # become stale if the contents of used JS files change while the configuration remains
      # unchanged.
      JSCTX = ::Kramdown::Utils::LRUCache.new(10)

      # +ExecJS+ uses <tt>runtime = Runtimes.const_get(name)</tt> without checks. That is fragile
      # and potentially insecure with arbitrary user input. Instead we use a fixed dictionary
      # restricted to valid contents. Note that there are aliases like <tt>SpiderMonkey =
      # Spidermonkey</tt>.
      JSRUN_FROMSYM = {}.tap do |dict|
        ExecJS::Runtimes.constants.each do |name|
          runtime = ExecJS::Runtimes.const_get(name)
          dict[name] = runtime if runtime.is_a?(ExecJS::Runtime)
        end
      end

      # Subclasses of +ExecJS::Runtime+ provide +.name+ (too verbose), but not, say, +.symbol+. This
      # dictionary associates each JS runtime class with a representative symbol. For aliases like
      # <tt>SpiderMonkey = Spidermonkey</tt>, an unspecified choice is made.
      JSRUN_TOSYM = JSRUN_FROMSYM.invert

      # Dictionary for escape sequences used in Javascript string literals
      JS_ESCAPE = {
        "\\" => "\\\\",
        "\"" => "\\\"",
        # Escaping single quotes not necessary in double-quoted string literals
        #"'" => "\\'",
        # JS does not recognize \a nor GNU's \e
        # \b is ambiguous in regexps, as in Perl and Ruby
        #"\b" => "\\b",
        "\f" => "\\f",
        "\n" => "\\n",
        "\r" => "\\r",
        "\t" => "\\t",
        "\v" => "\\v",
      }

      class << self
        private

        # Turn a string into an equivalent Javascript literal, double-quoted. Similar to +.to_json+,
        # but escape all non-ASCII codes as well.
        def js_quote(str)
          # No portable way of escaping Unicode points above 0xFFFF
          '"%s"' % str.gsub(/[\0-\u{001F}""\\\u{0080}-\u{FFFF}]/u) do |c|
            JS_ESCAPE[c] || "\\u%04x" % c.ord
          end
        end

        # This should really be provided by +ExecJS::Runtimes+: A list of available JS engines, as
        # symbols, in the order of preference.
        def available_jsruns
          ExecJS::Runtimes.runtimes.select(&:available?).map(&JSRUN_TOSYM)
        end

        # Configuration dicts contain keys in both string and symbol form. This bloats the output of
        # +.to_json+ with duplicate key-value pairs. While this does not affect the result, it looks
        # strange in logfiles. Therefore here is a function that recursively dedups dict keys.
        # Nondestructive.
        def dedup_keys(conf)
          # Lazy solution would be: JSON.parse(conf.to_json)
          case conf
          when Hash
            conf.reject {|key, _| key.is_a?(Symbol) && conf.has_key?(key.to_s) }.
              tap {|dict| dict.each {|key, value| dict[key] = dedup_keys(value) } }
          when Array
            conf.map { |value| dedup_keys(value) }
          else
            conf
          end
        end

        # Return a closure that logs verbose-level messages to the appropriate channel(s). With the
        # debug option set, the debug channel gets a copy as well.
        #
        # Usage:
        #     log = logger(converter); ...; log.call {msg}; ...
        #
        # If no logging needs to be done, the <tt>{msg}</tt> is not evaluated.
        def logger(converter)
          config = converter.options[:math_engine_opts]
          verbose = config[:verbose]
          debug = config[:debug]
          if verbose || debug
            lambda do |&expr|
              msg = expr.call
              warn(msg) if debug
              converter.warning(msg) if verbose
            end
          else
            lambda { |&expr| }
          end
        end

        # Given a +Converter+ object, return a JS engine context, initialized with the JS helper
        # files and with a JS object +katexopts+ containing general KaTeX options, as configured
        # with the converter's +math_engine_opts+. Cache the engine context reference for reuse.
        def js_context(converter)
          config = converter.options[:math_engine_opts]
          JSCTX[config] ||= begin
            log = logger(converter)

            jsrun = (config[:jsrun] || ENV_EXECJS_RUNTIME ||
                     JSRUN_TOSYM[ExecJS::Runtimes.best_available] || 'Disabled').to_s.to_sym
            ExecJS.runtime = JSRUN_FROMSYM[jsrun]
            log.call { "Available JS runtimes: #{available_jsruns.join(', ')}" }
            log.call { "Selected JS runtime: #{jsrun}" }

            jsdir = config[:jsdir] || DEFAULT_JSDIR
            katexjs = config[:katexjs] || DEFAULT_KATEXJS
            libs = config[:libs] || DEFAULT_LIBS

            # ExecJS.compile is not incremental, so we have to concatenate sources
            js = ''
            libs.each do |libfile|
              absfile = File.expand_path(libfile, jsdir)
              log.call { "Loading JS file: #{absfile}" }
              js << IO.read(absfile, external_encoding: Encoding::UTF_8) << "\n"
            end
            log.call { "Loading KaTeX JS file: #{katexjs}" }
            js << IO.read(katexjs, external_encoding: Encoding::UTF_8) << "\n"

            # Initialize JS variable katexopts
            katexopts = config[:katexopts] || {}
            jskatexopts = "var katexopts = #{dedup_keys(katexopts).to_json}"
            log.call { "JS eval: #{jskatexopts}" }
            js << jskatexopts << "\n"

            ExecJS.compile(js)
          end
        end

        # Given a +Converter+ object and a TeX math fragment _tex_ as well as a _display_mode_
        # (either +:block+ or +:inline+), run the JS engine and let KaTeX compile the math fragment.
        # Return the resulting HTML string. Can raise errors if something in the process fails.
        def compile_tex_math(converter, tex, display_mode)
          config = converter.options[:math_engine_opts]
          ctx = js_context(converter)
          js = "tex_to_html(#{js_quote(tex)}, #{(display_mode == :block).to_json}, katexopts)"
          warn "JS eval: #{js}" if config[:debug]
          ans = ctx.eval(js)
          unless ans && ans.start_with?('<') && ans.end_with?('>')
            raise Kramdown::Error, "Server-side KaTeX rendering failed: #{js}"
          end
          ans
        end

        public

        # The function used by kramdown for rendering TeX math to HTML
        def call(converter, el, opts)
          display_mode = el.options[:category]
          ans = compile_tex_math(converter, el.value, display_mode)
          attr = el.attr.dup
          attr.delete('xmlns')
          attr.delete('display')
          ans.insert(ans =~ /[[:space:]>]/, converter.html_attributes(attr))
          ans = ' ' * opts[:indent] << ans << "\n" if display_mode == :block
          ans
        end

      end
    end
  end
end
