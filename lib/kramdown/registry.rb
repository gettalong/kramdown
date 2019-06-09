# -*- coding: utf-8; frozen_string_literal: true -*-
#
#--
# Copyright (C) 2009-2019 Thomas Leitner <t_leitner@gmx.at>
#
# This file is part of kramdown which is licensed under the MIT.
#++
#

module Kramdown

  # A singleton class that cannot be initialized.
  # It stores data as key-value pairs similar to Hash objects.
  class Registry

    class << self
      undef :new

      # Primary endpoint to retrieve or stash data based on the +#hash+ value of given +key+ along
      # with an optional block.
      #
      # If the key's hash value doesn't exist in the registry, the given block is evaluated in
      # the context of the key. The result is both returned and stashed in the registry, otherwise
      # the hash value is looked up in the registry.
      #
      # The key needs to be a *non-empty* object that responds to a +:empty?+. If not, the given
      # block is evaluated in the context of the key and the result is simply returned.
      # Otherwise, the given key is returned.
      def getset(key)
        @registry ||= {}

        if stashable?(key)
          digest = key.hash
          if @registry.key?(digest)
            @registry[digest]
          else
            @registry[digest] = block_given? ? yield(key) : nil
          end
        else
          block_given? ? yield(key) : key
        end
      end

      # Delete given +key+ and associated value from the registry
      def delete(key)
        @registry.delete(key.hash)
      end

      # Clear all data stashed in the registry.
      def reset
        @registry.clear
      end

      private

      def stashable?(key)
        key.respond_to?(:empty) && !key.empty?
      end

    end

  end

end
