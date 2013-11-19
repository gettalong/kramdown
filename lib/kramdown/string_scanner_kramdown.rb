# -*- coding: utf-8 -*-

# This patched StringScanner adds line number information for current scan
# position and a start_line_number override for nested StringScanners.
require 'strscan'
class StringScannerKramdown < StringScanner

  # Set start_line_number to handle nested StringScanners that scan a sub-string
  # of the source document. Kramdown uses this e.g., for span level parsers.
  attr_accessor :start_line_number

  # To make this unicode (multibyte) aware, we have to use charpos which was
  # added in Ruby version 2.0.0.
  # This method will work with older versions of Ruby, however it will report
  # incorrect line numbers if the scanned string contains multibyte characters.
  if instance_methods.include?(:charpos)
    def best_pos
      charpos
    end
  else
    def best_pos
      pos
    end
  end

  # Returns the line number for current charpos.
  # NOTE: Requires that all line endings are normalized to '\n'
  # NOTE: Normally we'd have to add one to the count of newlines to get the
  # correct line number. However we add the one indirectly by using a one-based
  # start_line_number.
  def current_line_number
    string[0..best_pos].count("\n") + (start_line_number || 1)
  end

end
