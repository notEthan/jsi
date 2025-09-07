# frozen_string_literal: true

require_relative 'test_helper'

describe(JSI::Schema::Dialect) do
  it("is pretty") do
    assert_equal(%q(#<JSI::Schema::Dialect id: <tag:6aq>>), JSI::Schema::Dialect.new(id: 'tag:6aq', vocabularies: []).inspect)
    assert_equal(%q(#<JSI::Schema::Dialect id: <tag:6aq>>), JSI::Schema::Dialect.new(id: 'tag:6aq', vocabularies: []).pretty_inspect.chomp)
    assert_equal(%q(#<JSI::Schema::Dialect id: <tag:6aq>>), JSI::Schema::Dialect.new(id: 'tag:6aq', vocabularies: [JSI::Schema::Vocabulary.new(elements: [])]).pretty_inspect.chomp)
    assert_equal(%q(#<JSI::Schema::Dialect >), JSI::Schema::Dialect.new(vocabularies: []).pretty_inspect.chomp)
    assert_equal(%q(#<JSI::Schema::Dialect #<JSI::Schema::Vocabulary >>), JSI::Schema::Dialect.new(vocabularies: [JSI::Schema::Vocabulary.new(elements: [])]).pretty_inspect.chomp)
  end
end

describe(JSI::Schema::Vocabulary) do
  it("is pretty") do
    assert_equal(%q(#<JSI::Schema::Vocabulary id: <tag:7aq>>), JSI::Schema::Vocabulary.new(id: 'tag:7aq', elements: []).inspect)
    assert_equal(%q(#<JSI::Schema::Vocabulary id: <tag:7aq>>), JSI::Schema::Vocabulary.new(id: 'tag:7aq', elements: []).pretty_inspect.chomp)
    assert_equal(%q(#<JSI::Schema::Vocabulary id: <tag:7aq>>), JSI::Schema::Vocabulary.new(id: 'tag:7aq', elements: [JSI::Schema::Element.new { }]).pretty_inspect.chomp)
    assert_equal(%q(#<JSI::Schema::Vocabulary >), JSI::Schema::Vocabulary.new(elements: []).pretty_inspect.chomp)
    assert_match(/\A#<JSI::Schema::Vocabulary #<JSI::Schema::Element.*>>\z/, JSI::Schema::Vocabulary.new(elements: [JSI::Schema::Element.new { }]).inspect)
  end
end

$test_report_file_loaded[__FILE__]
