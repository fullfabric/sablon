require 'test_helper'

class EnvironmentTest < Sablon::TestCase
  def test_transforms_internal_hash
    context = Sablon::Context.transform_hash(a: 1, b: { c: 2, "d" => 3 })
    env = Sablon::Environment.new(nil, a: 1, b: { c: 2, "d" => 3 })
    #
    assert_nil env.template
    assert_equal context, env.context
  end

  def test_alter_context
    # set initial context
    env = Sablon::Environment.new(nil, a: 1, b: { c: 2, "d" => 3 })

    # alter context to change a single key and set a new one
    env2 = env.alter_context(a: "a", e: "new-key")
    assert_equal({ "a" => "a", "b" => { "c" => 2, "d" => 3 }, "e" => "new-key" }, env2.context)

    # check that the old context was not modified
    assert_equal({"a" => 1, "b" => { "c" => 2, "d" => 3 }}, env.context)

    # check that numbering and template are the same references
    assert env.template.equal?(env2.template), "#{env.template} != #{env2.template}"

    # check that a new context reference was created
    assert !env.context.equal?(env2.context), "#{env.context} == #{env2.context}"
  end

  def test_alter_context_keeps_the_observer
    observer = ->(_event, *_subjects, &block) { block.call }
    env = Sablon::Environment.new(nil, { a: 1 }, observer)

    assert_same observer, env.observer
    assert_same observer, env.alter_context(a: 2).observer
  end

  def test_observer_is_nil_by_default
    assert_nil Sablon::Environment.new(nil, a: 1).observer
  end

  def test_observe_without_observer_yields_and_returns_the_block_value
    env = Sablon::Environment.new(nil, a: 1)
    calls = 0

    result = env.observe(:statement, :subject) do
      calls += 1
      :done
    end

    assert_equal :done, result
    assert_equal 1, calls
  end

  def test_observe_with_observer_delegates_and_returns_the_observer_result
    seen = []
    observer = lambda do |event, *subjects, &block|
      seen << [event, subjects]
      block.call
      :from_observer
    end
    env = Sablon::Environment.new(nil, { a: 1 }, observer)
    calls = 0

    result = env.observe(:insertion, :field, 'raw') { calls += 1 }

    assert_equal :from_observer, result
    assert_equal 1, calls
    assert_equal [[:insertion, [:field, 'raw']]], seen
  end
end
