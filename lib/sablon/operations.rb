module Sablon
  module Statement
    class Insertion < Struct.new(:expr, :field)
      def evaluate(env)
        if content = expr.evaluate(env.context)
          field.replace(Sablon::Content.wrap(content))
        else
          field.remove
        end
      end
    end

    class Loop < Struct.new(:list_expr, :iterator_name, :block)
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
        block.replace(content.reverse) if block
      end
    end

    class Condition < Struct.new(:conditon_expr, :block, :predicate)
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

    class ExpressiveCondition < Struct.new(:left_operand, :operator, :right_operand, :block)
      def evaluate(env)
        # Support both string literal and expression evaluation
        left = parse_operand(left_operand, env)

        right = parse_operand(right_operand, env)

        if build_operation(operator, left, right).call
          block.replace(block.process(env).reverse)
        else
          block.replace([])
        end
      end

      private

      def build_operation(operator, left, right)
        operations = {
          '==' => -> { left == right },
          '!=' => -> { left != right },
          '<' => -> { left < right },
          '>' => -> { left > right },
          '<=' => -> { left <= right },
          '>=' => -> { left >= right }
        }
        raise ArgumentError, "Unknown operator: #{operator}" unless operations.key?(operator)

        operations[operator]
      end

      def parse_operand(operand, env)
        if operand.start_with?('"', "'")
          operand[1..-2]
        else
          Expression.parse(operand).evaluate(env)
        end
      end
    end

    class Comment < Struct.new(:block)
      def evaluate(_env)
        block.replace []
      end
    end

    class Image < Struct.new(:image_reference, :block)
      def evaluate(context)
        image = image_reference.evaluate(context)
        block.replace([image])
      end
    end
  end

  module Expression
    class Variable < Struct.new(:name)
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

    class LookupOrMethodCall < Struct.new(:receiver_expr, :expression)
      def evaluate(context)
        return unless receiver = receiver_expr.evaluate(context)

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
