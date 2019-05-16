# frozen_string_literal: true

$LOAD_PATH.unshift File.join(__dir__, '../lib')

require 'kramdown'
require 'memory_profiler'
require 'minitest'
require 'rouge'

class Rouge::Formatters::HTMLLegacy
  def format(tokens, &b)
    super(tokens, &b).sub(/<\/code><\/pre>\n?/, "</code></pre>\n")
  end
end

class RougeHTMLFormatters < Rouge::Formatters::HTMLLegacy
  def stream(tokens, &b)
    yield '<div class="custom-class">'
    super
    yield '</div>'
  end
end

Encoding.default_external = 'utf-8'

class KdProfiler
  include Minitest::Assertions
  attr_accessor :assertions

  DEFAULT_OPTS = { auto_ids: false, footnote_nr: 1 }

  def initialize
    @assertions = 0
  end

  def assert_test_cases
    Dir[File.join(__dir__, '../test/testcases/**/*.text')].each do |text_file|
      basename  = text_file.sub(/\.text$/, '')
      opts_file = text_file.sub(/\.text$/, '.options')

      (Dir[basename + ".*"] - [text_file, opts_file]).each do |output_file|
        output_format = File.extname(output_file)[1..-1]
        next unless Kramdown::Converter.const_defined?(output_format.capitalize)

        opts_file = File.join(File.dirname(text_file), 'options') unless File.exist?(opts_file)
        options   = File.exist?(opts_file) ? YAML.load(File.read(opts_file)) : DEFAULT_OPTS

        result = Kramdown::Document.new(File.read(text_file), options).send("to_#{output_format}")
        assert_equal result, File.read(output_file)
      end
    end
  end
end

start = Time.now
print "\nProfiling... "

report = MemoryProfiler.report(allow_files: 'kramdown') { KdProfiler.new.assert_test_cases }
puts "Done in #{(Time.now - start).round(2)} seconds."
puts "Generating results.."
puts

print_opts = {scale_bytes: true}

unless ENV['CI']
  total_allocated_output = report.scale_bytes(report.total_allocated_memsize)
  total_retained_output  = report.scale_bytes(report.total_retained_memsize)

  puts "-" * 50
  puts "Total allocated: #{total_allocated_output} (#{report.total_allocated} objects)"
  puts "Total retained:  #{total_retained_output} (#{report.total_retained} objects)"
  puts "-" * 50

  report_file = '.memprof.tmp'
  print_opts.merge!(to_file: report_file)
  puts "\nDetailed report saved to '#{report_file}'"
end
report.pretty_print(print_opts)
