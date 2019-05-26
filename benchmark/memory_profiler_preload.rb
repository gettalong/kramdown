# frozen_string_literal: true

BEGIN {
  require 'memory_profiler'
  start = Time.now
  puts "\nProfiling...\n\n"

  MemoryProfiler.start(allow_files: 'kramdown')
}

END {
  report = MemoryProfiler.stop

  puts "\nDone in #{(Time.now - start).round(2)} seconds."
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

    report_file = 'memory_profile.tmp'
    print_opts.merge!(to_file: report_file)
    puts "\nDetailed report saved to '#{report_file}'"
  end
  report.pretty_print(print_opts)
}
