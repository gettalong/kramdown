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

class TestFiles < Test::Unit::TestCase

  # Generate test methods for kramdown-to-xxx conversion
  Dir[File.dirname(__FILE__) + '/testcases/**/*.text'].each do |text_file|
    basename = text_file.sub(/\.text$/, '')
    opts_file = text_file.sub(/\.text$/, '.options')
    (Dir[basename + ".*"] - [text_file, opts_file]).each do |output_file|
      output_format = File.extname(output_file)[1..-1]
      next if !Kramdown::Converter.const_defined?(output_format[0..0].upcase + output_format[1..-1])
      define_method('test_' + text_file.tr('.', '_') + "_to_#{output_format}") do
        opts_file = File.join(File.dirname(text_file), 'options') if !File.exist?(opts_file)
        options = File.exist?(opts_file) ? YAML::load(File.read(opts_file)) : {:auto_ids => false, :filter_html => [], :footnote_nr => 1}
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
                          'test/testcases/block/09_html/simple.html' # bc of xml elements
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
    result = IO.popen("tidy -q -raw 2>/dev/null", 'r+') do |io|
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

end
