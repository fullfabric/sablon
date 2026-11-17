# frozen_string_literal: true

module Sablon
  # Combines the user supplied context and template into a single object
  # to manage data during template processing.
  class Environment
    attr_reader :template
    attr_reader :context
    attr_reader :section_properties
    attr_reader :observer

    # returns a new environment with merged contexts
    def alter_context(context = {})
      new_context = @context.merge(context)
      Environment.new(template, new_context, observer)
    end

    # Reports a unit of work to the optional render observer. The observer
    # responds to +call(event, *subjects)+ and receives a block that performs
    # Sablon's work; it must call that block exactly once and return its
    # value. Exceptions raised by the block propagate through the observer.
    def observe(event, *subjects)
      return yield unless observer

      observer.call(event, *subjects) { yield }
    end

    # reader method for the DOM::Model instance stored on the template
    def document
      @template.document
    end

    def section_properties=(properties)
      @section_properties = Context.transform_hash(properties)
    end

    private

    def initialize(template, context = {}, observer = nil)
      @template = template
      @observer = observer
      @context = Context.transform_hash(context)
    end
  end
end
