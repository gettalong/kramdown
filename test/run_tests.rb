$:.unshift File.dirname(__FILE__) + '/../lib'
require 'kramdown'
require 'test/unit/assertions'
require 'yaml'
require 'pp'

include Test::Unit::Assertions

arg = ARGV[0] || File.dirname(__FILE__) + '/testcases'

arg = if File.directory?(arg)
        File.join(arg, '**/*.text')
      else
        arg + '.text'
      end

width = 60;
Dir[arg].each {|f| width = [width, f.length].max }.each do |file|
  print(('Testing file ' + file + '   ').ljust(width))
  $stdout.flush

  html_file = file.sub('.text', '.html')
  options = YAML::load(File.read(file.sub('.text', '.options'))) rescue {}
  doc = Kramdown::Document.new(File.read(file), options)
  #pp doc if $VERBOSE
  begin
    assert_equal(File.read(html_file), doc.to_html)
    puts 'PASSED'
  rescue
    puts 'FAILED'
    puts $!.message if $VERBOSE
  end
end
