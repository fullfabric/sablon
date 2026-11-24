# frozen_string_literal: true

require 'test_helper'
require 'support/document_xml_helper'
require 'support/xml_snippets'

class ProcessorBlockTest < Sablon::TestCase
  include DocumentXMLHelper
  include XMLSnippets

  Block = Sablon::Processor::Document::Block
  RowBlock = Sablon::Processor::Document::RowBlock

  # Nokogiri answers ancestors(selector) by searching the whole tree from its root, so a render that calls it for
  # each field or block grows with the size of the part squared. Raises on such a call while a block runs.
  module SelectorAncestorsForbidden
    def ancestors(selector = nil)
      raise "ancestors(#{selector}) searches the whole tree" if selector && Thread.current[:selector_ancestors_forbidden]

      super
    end
  end
  Nokogiri::XML::Node.prepend(SelectorAncestorsForbidden)

  def test_rendering_finds_paragraphs_and_rows_without_searching_the_tree
    item = Struct.new(:index, :label, :rating)
    renders = {
      'simple_fields' => { 'first_name' => 'Jack', 'last_name' => 'Davis' },
      'complex_field' => { 'last_name' => 'Zane' },
      'paragraph_loop' => { 'technologies' => %w[Ruby Rails] },
      'table_row_loop' => { 'items' => [item.new('1.', 'Milk', '***')] },
      'conditional_inline' => { 'middle_name' => true },
      'complex_field_inline_conditional' => { 'boolean' => false }
    }

    renders.each do |name, context|
      forbidding_selector_ancestors { process(snippet(name), context) }
    end
  end
  def test_parent_is_the_nearest_paragraph
    doc = wrap(<<-XML)
      <w:tbl><w:tr><w:tc>
        <w:p><w:r><w:t id="inner">x</w:t></w:r></w:p>
      </w:tc></w:tr></w:tbl>
    XML

    assert_equal paragraph_of(doc, 'inner'), Block.parent(node(doc, 'inner'))
  end

  def test_parent_of_a_merge_field_is_the_paragraph_it_is_in
    doc = wrap(<<-XML)
      <w:p id="field"><w:fldSimple w:instr=" MERGEFIELD =name \\* MERGEFORMAT "><w:r><w:t>«=name»</w:t></w:r></w:fldSimple></w:p>
    XML
    field = Sablon::Parser::MailMerge.new.parse_fields(doc).first

    assert_equal 'field', Block.parent(field)['id']
  end

  def test_parent_row_is_the_innermost_row_of_nested_tables
    doc = wrap(<<-XML)
      <w:tbl><w:tr id="outer"><w:tc>
        <w:tbl><w:tr id="inner"><w:tc><w:p><w:r><w:t id="text">x</w:t></w:r></w:p></w:tc></w:tr></w:tbl>
      </w:tc></w:tr></w:tbl>
    XML

    assert_equal 'inner', RowBlock.parent(node(doc, 'text'))['id']
  end

  def test_parent_skips_a_paragraph_of_another_namespace
    doc = wrap(<<-XML)
      <w:p id="outer"><w:r><a:p xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
        <a:r><a:t id="text">x</a:t></a:r>
      </a:p></w:r></w:p>
    XML

    assert_equal 'outer', Block.parent(node(doc, 'text'))['id']
  end

  def test_parent_inside_a_paragraph_taken_out_of_the_document_is_nil
    doc = wrap('<w:p id="taken"><w:r><w:t id="text">x</w:t></w:r></w:p>')
    paragraph = node(doc, 'taken').unlink

    assert_nil Block.parent(paragraph.at_xpath(".//*[@id='text']"))
  end

  def test_parent_of_a_node_outside_any_paragraph_is_nil
    doc = wrap('<w:sectPr id="section"/>')

    assert_nil Block.parent(node(doc, 'section'))
  end

  def test_parent_inside_a_copy_outside_the_document_tree
    doc = wrap('<w:p id="source"><w:r><w:t id="text">x</w:t></w:r></w:p>')
    sandbox = Nokogiri::XML::Node.new('tmp', doc)
    sandbox.children = Nokogiri::XML::NodeSet.new(doc, [node(doc, 'source').dup])

    copy = sandbox.at_xpath(".//*[@id='text']")
    assert_equal sandbox.children.first, Block.parent(copy)
  end

  private

  def forbidding_selector_ancestors
    Thread.current[:selector_ancestors_forbidden] = true
    yield
  ensure
    Thread.current[:selector_ancestors_forbidden] = nil
  end

  def process(document, context)
    env = Sablon::Environment.new(MockTemplate.new, context)
    env.document.current_entry = 'word/document.xml'
    Sablon::Processor::Document.process(wrap(document), env)
  end

  def node(doc, id)
    doc.at_xpath("//*[@id='#{id}']")
  end

  def paragraph_of(doc, id)
    node(doc, id).ancestors.find { |ancestor| ancestor.name == 'p' }
  end
end
