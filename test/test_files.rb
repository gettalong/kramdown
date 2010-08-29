# -*- coding: utf-8 -*-
#
#--
# Copyright (C) 2009 Thomas Leitner <t_leitner@gmx.at>
#
# This file is part of kramdown.
#
# kramdown is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#++
#

require 'test/unit'
require 'kramdown'
require 'yaml'
require 'tmpdir'

Encoding.default_external = 'utf-8' if RUBY_VERSION >= '1.9'

class TestFiles < Test::Unit::TestCase

  # Generate test methods for kramdown-to-xxx conversion
  Dir[File.dirname(__FILE__) + '/testcases/**/*.text'].each do |text_file|
    basename = text_file.sub(/\.text$/, '')
    opts_file = text_file.sub(/\.text$/, '.options')
    (Dir[basename + ".*"] - [text_file, opts_file]).each do |output_file|
      next if (RUBY_VERSION >= '1.9' && File.exist?(output_file + '.19')) ||
        (RUBY_VERSION < '1.9' && output_file =~ /\.19$/)
      output_format = File.extname(output_file.sub(/\.19$/, ''))[1..-1]
      next if !Kramdown::Converter.const_defined?(output_format[0..0].upcase + output_format[1..-1])
      define_method('test_' + text_file.tr('.', '_') + "_to_#{output_format}") do
        opts_file = File.join(File.dirname(text_file), 'options') if !File.exist?(opts_file)
        options = File.exist?(opts_file) ? YAML::load(File.read(opts_file)) : {:auto_ids => false, :footnote_nr => 1}
        doc = Kramdown::Document.new(File.read(text_file), options)
        assert_equal(File.read(output_file), doc.send("to_#{output_format}"))
      end
    end
  end

  # Generate test methods for html-to-html conversion
  `tidy -v 2>&1`
  if $?.exitstatus != 0
    warn("Skipping html-to-html tests because tidy executable is missing")
  else
    EXCLUDE_HTML_FILES = ['test/testcases/block/06_codeblock/whitespace.html', # bc of span inside pre
                          'test/testcases/block/09_html/simple.html', # bc of xml elements
                          'test/testcases/span/03_codespan/highlighting.html', # bc of span elements inside code element
                         ]
    Dir[File.dirname(__FILE__) + '/testcases/**/*.html'].each do |html_file|
      next if EXCLUDE_HTML_FILES.any? {|f| html_file =~ /#{f}$/}
      define_method('test_' + html_file.tr('.', '_') + "_to_html") do
        doc = Kramdown::Document.new(File.read(html_file), :input => 'html', :auto_ids => false, :footnote_nr => 1)
        assert_equal(tidy_output(File.read(html_file)), tidy_output(doc.to_html))
      end
    end
  end

  def tidy_output(out)
    cmd = "tidy -q --doctype omit #{RUBY_VERSION >= '1.9' ? '-utf8' : '-raw'} 2>/dev/null"
    result = IO.popen(cmd, 'r+') do |io|
      io.write(out)
      io.close_write
      io.read
    end
    if $?.exitstatus == 2
      raise "Problem using tidy"
    end
    result
  end

  # Generate test methods for text-to-latex conversion and compilation
  `latex -v 2>&1`
  if $?.exitstatus != 0
    warn("Skipping latex compilation tests because latex executable is missing")
  else
    EXCLUDE_LATEX_FILES = ['test/testcases/span/01_link/image_in_a.text', # bc of image link
                           'test/testcases/span/01_link/imagelinks.text', # bc of image links
                           'test/testcases/span/04_footnote/markers.text', # bc of footnote in header
                          ]
    Dir[File.dirname(__FILE__) + '/testcases/**/*.text'].each do |text_file|
      next if EXCLUDE_LATEX_FILES.any? {|f| text_file =~ /#{f}$/}
      define_method('test_' + text_file.tr('.', '_') + "_to_latex_compilation") do
        latex =  Kramdown::Document.new(File.read(text_file),
                                                          :auto_ids => false, :footnote_nr => 1,
                                                          :template => 'document').to_latex
        result = IO.popen("latex -output-directory='#{Dir.tmpdir}' 2>/dev/null", 'r+') do |io|
          io.write(latex)
          io.close_write
          io.read
        end
        assert($?.exitstatus == 0, result.scan(/^!(.*\n.*)/).join("\n"))
      end
    end
  end

  # Generate test methods for text->kramdown->html conversion
  `tidy -v 2>&1`
  if $?.exitstatus != 0
    warn("Skipping text->kramdown->html tests because tidy executable is missing")
  else
    EXCLUDE_TEXT_FILES = ['test/testcases/span/05_html/markdown_attr.text',  # bc of markdown attr
                          'test/testcases/block/09_html/markdown_attr.text', # bc of markdown attr
                          'test/testcases/span/extension/options.text',      # bc of parse_span_html option
                          'test/testcases/block/12_extension/options.text',  # bc of options option
                          'test/testcases/block/12_extension/options3.text', # bc of options option
                          'test/testcases/block/09_html/content_model/tables.text',  # bc of parse_block_html option
                          'test/testcases/block/09_html/html_to_native/header.text', # bc of auto_ids option that interferes
                          'test/testcases/block/09_html/simple.text',        # bc of webgen:block elements
                          'test/testcases/block/11_ial/simple.text',         # bc of change of ordering of attributes in header
                          'test/testcases/span/extension/comment.text',      # bc of comment text modifications (can this be avoided?)
                         ]
    Dir[File.dirname(__FILE__) + '/testcases/**/*.text'].each do |text_file|
      next if EXCLUDE_TEXT_FILES.any? {|f| text_file =~ /#{f}$/}
      define_method('test_' + text_file.tr('.', '_') + "_to_kramdown_to_html") do
        html_file = text_file.sub(/\.text$/, '.html')
        html_file += '.19' if RUBY_VERSION >= '1.9' && File.exist?(html_file + '.19')
        opts_file = text_file.sub(/\.text$/, '.options')
        opts_file = File.join(File.dirname(text_file), 'options') if !File.exist?(opts_file)
        options = File.exist?(opts_file) ? YAML::load(File.read(opts_file)) : {:auto_ids => false, :footnote_nr => 1}
        kdtext = Kramdown::Document.new(File.read(text_file), options).to_kramdown
        html = Kramdown::Document.new(kdtext, options).to_html
        assert_equal(tidy_output(File.read(html_file)), tidy_output(html))
      end
    end
  end

  # Generate test methods for html-to-kramdown-to-html conversion
  `tidy -v 2>&1`
  if $?.exitstatus != 0
    warn("Skipping html-to-kramdown-to-html tests because tidy executable is missing")
  else
    EXCLUDE_HTML_KD_FILES = ['test/testcases/span/extension/options.html',        # bc of parse_span_html option
                             'test/testcases/span/05_html/normal.html',           # bc of br tag before closing p tag
                             'test/testcases/block/12_extension/nomarkdown.html', # bc of nomarkdown extension
                             'test/testcases/block/09_html/simple.html',          # bc of webgen:block elements
                             'test/testcases/block/09_html/markdown_attr.html',   # bc of markdown attr
                             'test/testcases/block/09_html/html_to_native/table_simple.html', # bc of invalidly converted simple table
                             'test/testcases/block/06_codeblock/whitespace.html', # bc of entity to char conversion
                             'test/testcases/block/11_ial/simple.html',           # bc of change of ordering of attributes in header
                             'test/testcases/span/03_codespan/highlighting.html', # bc of span elements inside code element
                            ]
    Dir[File.dirname(__FILE__) + '/testcases/**/*.html'].each do |html_file|
      next if EXCLUDE_HTML_KD_FILES.any? {|f| html_file =~ /#{f}$/}
      define_method('test_' + html_file.tr('.', '_') + "_to_kramdown_to_html") do
        kd = Kramdown::Document.new(File.read(html_file), :input => 'html', :auto_ids => false, :footnote_nr => 1).to_kramdown
        doc = Kramdown::Document.new(kd, :auto_ids => false, :footnote_nr => 1)
        assert_equal(tidy_output(File.read(html_file)), tidy_output(doc.to_html))
      end
    end
  end

end
