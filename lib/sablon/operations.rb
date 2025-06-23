# frozen_string_literal: true

module Sablon
  module Statement
    Insertion = Struct.new(:expr, :field) do
      def evaluate(env)
        if (content = expr.evaluate(env.context))
          field.replace(Sablon::Content.wrap(content))
        else
          field.remove
        end
      end
    end

    Loop = Struct.new(:list_expr, :iterator_name, :block) do
      def evaluate(env)
        value = list_expr.evaluate(env.context)
        value = [] if value.nil?
        value = value.to_ary if value.respond_to?(:to_ary)
        unless value.is_a?(Enumerable)
          raise ContextError,
                "The expression #{list_expr.inspect} should evaluate to an enumerable but was: #{value.inspect}"
        end

        content = value.flat_map do |item|
          iter_env = env.alter_context(iterator_name => item)
          block.process(iter_env)
        end
        block&.replace(content.reverse)
      end
    end

    Condition = Struct.new(:conditon_expr, :block, :predicate) do
      def evaluate(env)
        value = conditon_expr.evaluate(env.context)
        if truthy?(predicate ? value.public_send(predicate) : value)
          block.replace(block.process(env).reverse)
        else
          block.replace([])
        end
      end

      def truthy?(value)
        case value
        when Array
          !value.empty?
        else
          !!value
        end
      end
    end

    ExpressiveCondition = Struct.new(:left_operand, :operator, :right_operand, :block) do
      def evaluate(env)
        # Support both string literal and expression evaluation
        left = parse_operand(left_operand, env)
        right = parse_operand(right_operand, env)

        # Handle single-element arrays
        left = left.first if left.is_a?(Array) && left.size == 1
        right = right.first if right.is_a?(Array) && right.size == 1

        if build_operation(operator, left, right).call
          block.replace(block.process(env).reverse)
        else
          block.replace([])
        end
      end

      private

      def build_operation(operator, left, right)
        return -> { false } unless left && right

        operations = {
          '==' => -> { left == right },
          '!=' => -> { left != right },
          '<' => -> { left < right },
          '>' => -> { left > right },
          '<=' => -> { left <= right },
          '>=' => -> { left >= right },
          'includes' => -> { left.is_a?(Array) && left.include?(right) }
        }
        raise ArgumentError, "Unknown operator: #{operator}" unless operations.key?(operator)

        operations[operator]
      end

      def parse_operand(operand, env)
        if operand.start_with?('"', "'")
          operand[1..-2]
        elsif operand.match?(/^\d+$/)
          operand.to_i
        elsif operand.match?(/^\d+\.\d+$/)
          operand.to_f
        else
          Expression.parse(operand).evaluate(env)
        end
      end
    end

    Comment = Struct.new(:block) do
      def evaluate(_env)
        block.replace []
      end
    end

    Image = Struct.new(:image_reference, :block) do
      def evaluate(context)
        image = image_reference.evaluate(context)
        block.replace([image])
      end
    end
  end

  module Expression
    Variable = Struct.new(:name) do
      def evaluate(context)
        if context.is_a?(Hash)
          context[name]
        else
          context.context[name]
        end
      end

      def inspect
        "«#{name}»"
      end
    end

    LookupOrMethodCall = Struct.new(:receiver_expr, :expression) do
      def evaluate(context)
        return unless (receiver = receiver_expr.evaluate(context))

        expression.split('.').inject(receiver) do |local, m|
          case local
          when Hash
            local[m]
          else
            local.public_send m if local.respond_to?(m)
          end
        end
      end

      def inspect
        "«#{receiver_expr.name}.#{expression}»"
      end
    end

    def self.parse(expression)
      if expression.include?('.')
        parts = expression.split('.')
        LookupOrMethodCall.new(Variable.new(parts.shift), parts.join('.'))
      else
        Variable.new(expression)
      end
    end
  end
end
