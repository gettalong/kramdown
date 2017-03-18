// -*- coding: utf-8 -*-
//
// Copyright (C) 2017 Christian Cornelssen <ccorn@1tein.de>
//
// This file is part of kramdown which is licensed under the MIT.

// Transform non-ASCII characters and '\0' in given string to HTML numeric character references
function escape_nonascii_html(str) {
  return str.replace(/[^\x01-\x7F]/g, function (u) {
    return "&#x" + u.charCodeAt(0).toString(16) + ";";
  });
};
