# -*- coding: utf-8 -*-
#
#--
# Copyright (C) 2009-2013 Thomas Leitner <t_leitner@gmx.at>
#
# This file is part of kramdown which is licensed under the MIT.
#++
#

module Kramdown

  # == \Utils Module
  #
  # This module contains utility class/modules/methods that can be used by both parsers and
  # converters.
  module Utils

    autoload :Entities, 'kramdown/utils/entities'
    autoload :Html, 'kramdown/utils/html'
    autoload :OrderedHash, 'kramdown/utils/ordered_hash'
    autoload :Unidecoder, 'kramdown/utils/unidecoder'

    # Treat +name+ as if it were snake cased (e.g. snake_case) and camelize it (e.g. SnakeCase).
    def self.camelize(name)
      name.split('_').inject('') {|s,x| s << x[0..0].upcase + x[1..-1] }
    end

  end

end
