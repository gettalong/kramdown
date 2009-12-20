require 'benchmark'
require 'optparse'
require 'fileutils'

require 'kramdown'
require 'maruku'
require 'maruku/version'
begin
  require 'rdiscount'
  require 'bluecloth'
rescue LoadError
end
require 'bluefeather'

module MaRuKu::Errors
  def tell_user(s)
  end
end

options = {:static => false}
OptionParser.new do |opts|
  opts.on("-s", "--[no-]static", "Generate static data") {|v| options[:static] = v}
  opts.on("-g", "--[no-]graph", "Generate graph") {|v| options[:graph] = v}
  opts.on("-h NAME", "--historic NAME", String, "Add historic benchmark data") {|v| options[:historic] = v}
end.parse!


THISRUBY = (self.class.const_defined?(:RUBY_DESCRIPTION) ? RUBY_DESCRIPTION.scan(/^.*?(?=\s*\()/).first.sub(/\s/, '-') : "ruby-#{RUBY_VERSION}")

Dir.chdir(File.dirname(__FILE__))
$:.unshift "../lib"
BMDATA = File.read('mdbasics.text')
MULTIPLIER = (0..5).map {|i| 2**i}

if options[:static]
  static = {}
  2.times do
    MULTIPLIER.each do |i|
      $stderr.puts "Generating static benchmark data, multiplier #{i}"
      mddata = BMDATA*i
      static[i] = []
      static[i] << ["Maruku #{MaRuKu::Version}", Benchmark::measure { Maruku.new(mddata, :on_error => :ignore).to_html }.real]
      static[i] << ["BlueFeather #{BlueFeather::VERSION}", Benchmark::measure { BlueFeather.parse(mddata) }.real]
      if self.class.const_defined?(:BlueCloth)
        static[i] << ["BlueCloth #{BlueCloth::VERSION}", Benchmark::measure { BlueCloth.new(mddata).to_html }.real]
      else
        static[i] << ["BlueCloth Not Available.", 0]
      end
      if self.class.const_defined?(:RDiscount)
        static[i] << ["RDiscount #{RDiscount::VERSION}", Benchmark::measure { RDiscount.new(mddata).to_html }.real]
      else
        static[i] << ["RDiscount Not Available.", 0]
      end
    end
  end
  File.open("static-#{THISRUBY}.dat", 'w+') do |f|
    f.puts "# " + static[MULTIPLIER.first].map {|name, val| name }.join(" || ")
    format_str = "%5d" + " %10.5f"*static[MULTIPLIER.first].size
    static.sort.each do |m,v|
      f.puts format_str % [m, *v.map {|name,val| val}]
    end
  end
end

if options[:historic]
  historic = "historic-#{THISRUBY}.dat"
  data = if File.exist?(historic)
           lines = File.readlines(historic).map {|l| l.chomp}
           lines.first << " || "
           lines
         else
           ["# ", *MULTIPLIER.map {|m| "%5d" % m}]
         end
  data.first << " #{options[:historic]}"
  MULTIPLIER.each_with_index do |m, i|
    $stderr.puts "Generating historic benchmark data, multiplier #{m}"
    mddata = BMDATA*m
    Benchmark::measure { Kramdown::Document.new(mddata).to_html }
    data[i+1] << " %10.5f" % Benchmark::measure { Kramdown::Document.new(mddata).to_html }.real
  end
  File.open(historic, 'w+') do |f|
    data.each {|l| f.puts l}
  end
end

if options[:graph]
  Dir['historic-*.dat'].each do |historic_name|
    theruby = historic_name.sub(/^historic-/, '').sub(/\.dat$/, '')
    graph_name = "graph-#{theruby}.png"
    static_name = "static-#{theruby}.dat"
    historic_names = File.readlines(historic_name).first.chomp[1..-1].split(/\s*\|\|\s*/)
    static_names = (File.exist?(static_name) ? File.readlines(static_name).first.chomp[1..-1].split(/\s*\|\|\s*/) : [])
    File.open("gnuplot.dat", "w+") do |f|
      f.puts <<EOF
set title "Execution Time Performance for #{theruby}"
set xlabel "File Multiplier (i.e. n times mdbasic.text)"
set ylabel "Execution Time in secondes"
set grid "on"
set terminal png
set output "#{graph_name}"
EOF
      f.print "plot "
      i, j = 1, 1
      f.puts((historic_names.map {|n| i += 1; "\"#{historic_name}\" using 1:#{i} with lp title \"#{n}\""} +
              static_names.map {|n| j += 1; n =~ /bluefeather/i ? nil : "\"#{static_name}\" using 1:#{j} with lp title \"#{n}\""}.compact).join(", "))
    end
    `gnuplot gnuplot.dat`
    FileUtils.rm("gnuplot.dat")
  end
end
