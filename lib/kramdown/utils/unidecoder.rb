# -*- coding: utf-8 -*-
#
#--
# Copyright (C) 2009-2013 Thomas Leitner <t_leitner@gmx.at>
#
# This file is part of kramdown which is licensed under the MIT.
#++
#
# This file is based on code originally from the Stringex library and needs the data files from
# Stringex to work correctly.

module Kramdown
  module Utils

    # Provides the ability to tranliterate Unicode strings into plain ASCII ones.
    module Unidecoder

      if RUBY_VERSION <= '1.8.6'
        def self.decode(string)
          string
        end
      else

        require 'stringex/unidecoder' # dummy require so that we can get at the data files

        # Transliterate string from Unicode into ASCII.
        def self.decode(string)
          string.gsub(/[^\x00-\x7f]/u) do |codepoint|
            begin
              unpacked = codepoint.unpack("U")[0]
              Stringex::Unidecoder::CODEPOINTS["x%02x" % (unpacked >> 8)][unpacked & 255]
            rescue
              "?"
            end
          end
        end

      end

    end

  end
end
