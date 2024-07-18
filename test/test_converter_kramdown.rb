# -*- coding: utf-8; frozen_string_literal: true -*-
#
#--
# Copyright (C) 2009-2019 Thomas Leitner <t_leitner@gmx.at>
#
# This file is part of kramdown which is licensed under the MIT.
#++
#

require 'minitest/autorun'
require 'kramdown/converter/kramdown'

describe Kramdown::Converter::Kramdown do
  it "converts weird html to kramdown" do
    html = <<~HTML
<ul>
  <li></li>
  <li>
    <p>one</p>
  </li>
  <li>
    <p>two</p>
  </li>
</ul>
    HTML
    doc, = Kramdown::Parser::Html.parse(html)
    md, = Kramdown::Converter::Kramdown.convert(doc)
    expected = <<~MD
* 
* one

* two

    MD
    assert_equal expected, md
  end
end
