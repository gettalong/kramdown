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

class TestFiles < Test::Unit::TestCase

  Dir[File.dirname(__FILE__) + '/testcases/**/*.text'].each do |file|
    %w( html latex ).each do |output_format|
      define_method('test_' + file.tr('.', '_') + "_to_#{output_format}") do
        out_file = file.sub('.text', ".#{output_format}")
        opts_file = file.sub('.text', '.options')
        opts_file = File.join(File.dirname(file), 'options') if !File.exist?(opts_file)
        options = File.exist?(opts_file) ? YAML::load(File.read(opts_file)) : {:auto_ids => false, :filter_html => [], :footnote_nr => 1}
        doc = Kramdown::Document.new(File.read(file), options)
        assert_equal(File.read(out_file), doc.send("to_#{output_format}"), "Failed test #{file}") if File.exists?(out_file)
      end
    end
  end

end
