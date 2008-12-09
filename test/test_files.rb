require 'test/unit'
require 'kramdown'
require 'yaml'

class TestFiles < Test::Unit::TestCase

  Dir[File.dirname(__FILE__) + '/testcases/**/*.text'].each do |file|
    define_method('test_' + file.tr('.', '_')) do
      html_file = file.sub('.text', '.html')
      assert_equal(File.read(html_file), Kramdown::Document.new(File.read(file)).to_html, "Failed test #{file}")
    end
  end

end
