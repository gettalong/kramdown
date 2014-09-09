# -*- coding: utf-8 -*-

require 'strscan'

module Kramdown
  module Utils

    # This patched StringScanner adds line number information for current scan position and a
    # start_line_number override for nested StringScanners.
    class StringScanner < ::StringScanner

      # The start line number. Used for nested StringScanners that scan a sub-string of the source
      # document. The kramdown parser uses this, e.g., for span level parsers.
      attr_reader :start_line_number

      # Takes the start line number as optional second argument.
      #
      # Note: The original second argument is no longer used so this should be safe.
      def initialize(string, start_line_number = 1)
        super(string)
        @start_line_number = start_line_number || 1
        @previous_pos = 0
        @previous_line_number = @start_line_number
      end

      # Sets the byte position of the scan pointer.
      #
      # Note: This also resets some internal variables, so always use pos= when setting the position
      # and don't use any other method for that!
      def pos=(pos)
        super
        @previous_line_number = @start_line_number
        @previous_pos = 0
      end

      # Returns the line number for current charpos.
      #
      # NOTE: Requires that all line endings are normalized to '\n'
      #
      # NOTE: Normally we'd have to add one to the count of newlines to get the correct line number.
      # However we add the one indirectly by using a one-based start_line_number.
      def current_line_number
        # Not using string[@previous_pos..best_pos].count('\n') because it is slower
        strscan = ::StringScanner.new(string)
        strscan.pos = @previous_pos
        old_pos = pos + 1
        @previous_line_number += 1 while strscan.skip_until(/\n/) && strscan.pos <= old_pos

        @previous_pos = (eos? ? pos : pos + 1)
        @previous_line_number
      end

    end

  end
end
