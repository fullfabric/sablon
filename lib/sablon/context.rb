module Sablon
  # A context represents the user supplied arguments to render a
  # template.
  #
  # This module contains transformation functions to turn a
  # user supplied hash into a data structure suitable for rendering the
  # docx template.
  module Context
    class << self; attr_accessor :content_regex end
    self.content_regex = /\A([^:]+):(.+)\z/

    class << self
      def transform_hash(hash)
        Hash[hash.map { |k, v| transform_pair(k.to_s, v) }]
      end

      private

      def transform_standard_key(key, value)
        case value
        when Hash
          [key, transform_hash(value)]
        when Array
          [key, value.map { |v| v.is_a?(Hash) ? transform_hash(v) : v }]
        else
          [key, value]
        end
      end

      def transform_pair(key, value)
        if match = content_regex.match(key)
          if value.nil?
            [match[2], value]
          else
            type_id = match[1].to_sym
            [match[2], Content.make(type_id, value)]
          end
        else
          transform_standard_key(key, value)
        end
      end
    end

    def self.values_of(context, definition)
      result = []

      if context.is_a?(definition)
        result << context
      elsif context && (context.is_a?(Enumerable) || context.is_a?(OpenStruct))
        context = context.to_h if context.is_a?(OpenStruct)
        result += context.collect do |key, value|
          if value
            values_of(value, definition)
          else
            values_of(key, definition)
          end
        end.compact
      end

      result.flatten.compact
    end  
  end
end
