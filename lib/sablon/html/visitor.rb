# frozen_string_literal: true

module Sablon
  class HTMLConverter
    class Visitor
      def visit(node)
        method_name = "visit_#{node.class.node_name}"
        return unless respond_to? method_name

        public_send method_name, node
      end
    end

    class GrepVisitor
      attr_reader :result

      def initialize(pattern)
        @pattern = pattern
        @result = []
      end

      def visit(node)
        return unless @pattern === node

        @result << node
      end
    end

    class LastNewlineRemoverVisitor < Visitor
      def visit_Paragraph(par)
        return unless par.runs.nodes.last.is_a?(HTMLConverter::Newline)

        par.runs.nodes.pop
      end
    end
  end
end
