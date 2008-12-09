$:.unshift File.dirname(__FILE__) + '/../lib'
require 'kramdown'
require 'test/unit/assertions'

include Test::Unit::Assertions

arg = ARGV[0] || File.dirname(__FILE__) + '/testcases'

arg = if File.directory?(arg)
        File.join(arg, '**/*.text')
      else
        arg + '.text'
      end

Dir[arg].each do |file|
  print 'Testing file ' + file + '   '
  $stdout.flush

  html_file = file.sub('.text', '.html')
  output = Kramdown::Document.new(File.read(file)).to_html
  begin
    assert_equal(File.read(html_file), output)
    puts 'PASSED'
  rescue
    puts 'FAILED'
    puts $!.message if $VERBOSE
  end
end
