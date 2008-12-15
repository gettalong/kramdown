require 'test/unit'
require 'kramdown'
require 'yaml'

class TestFiles < Test::Unit::TestCase

  Dir[File.dirname(__FILE__) + '/testcases/**/*.text'].each do |file|
    define_method('test_' + file.tr('.', '_')) do
      html_file = file.sub('.text', '.html')
      options = YAML::load(File.read(file.sub('.text', '.options'))) rescue {}
      doc = Kramdown::Document.new(File.read(file), options)
      assert_equal(File.read(html_file), doc.to_html, "Failed test #{file}")
    end
  end

end
