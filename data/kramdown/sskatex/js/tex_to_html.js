// -*- coding: utf-8 -*-
//
// Copyright (C) 2017 Christian Cornelssen <ccorn@1tein.de>
//
// This file is part of kramdown which is licensed under the MIT.

// Given a LaTeX math string, a boolean display_mode
// (true for block display, false for inline),
// and a dict katex_opts with general KaTeX options,
// return a string with corresponding HTML+MathML output.
// The implementation is allowed to set katex_opts.displayMode .
function tex_to_html(tex, display_mode, katex_opts) {
  katex_opts.displayMode = display_mode;
  return escape_nonascii_html(katex.renderToString(tex, katex_opts));
};
