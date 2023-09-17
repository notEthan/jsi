require_relative 'test_helper'

Examples = JSI.new_schema_module(YAML.load(<<~YAML
  $schema: http://json-schema.org/draft-07/schema
  definitions:
    with_none:
      definitions:
        with_none:
          title: with_none subschema without id or modname
        with_modname:
          title: with_none subschema with modname
        with_id:
          $id: tag:examples:with_none:with_id
          title: with_none subschema with id
        with_id_and_modname:
          $id: tag:examples:with_none:with_id_and_modname
          title: with_none subschema with id and modname
    with_modname:
      definitions:
        with_none:
          title: with_modname subschema without id or modname
        with_modname:
          title: with_modname subschema with modname
        with_id:
          $id: tag:examples:with_modname:with_id
          title: with_modname subschema with id
        with_id_and_modname:
          $id: tag:examples:with_modname:with_id_and_modname
          title: with_modname subschema with id and modname
    with_id:
      $id: tag:examples:with_id
      definitions:
        with_none:
          title: with_id subschema without id or modname
        with_modname:
          title: with_id subschema with modname
        with_id:
          $id: tag:examples:with_id:with_id
          title: with_id subschema with id
        with_id_and_modname:
          $id: tag:examples:with_id:with_id_and_modname
          title: with_id subschema with id and modname
    with_id_and_modname:
      $id: tag:examples:with_id_and_modname
      definitions:
        with_none:
          title: with_id_and_modname subschema without id or modname
        with_modname:
          title: with_id_and_modname subschema with modname
        with_id:
          $id: tag:examples:with_id_and_modname:with_id
          title: with_id_and_modname subschema with id
        with_id_and_modname:
          $id: tag:examples:with_id_and_modname:with_id_and_modname
          title: with_id_and_modname subschema with id and modname
  YAML
))

module Examples
  WithNone_WithModname = definitions['with_none'].definitions['with_modname']
  WithNone_WithIdAndModname = definitions['with_none'].definitions['with_id_and_modname']
  WithModname = definitions['with_modname']
  WithModname::WithModname = definitions['with_modname'].definitions['with_modname']
  WithModname::WithIdAndModname = definitions['with_modname'].definitions['with_id_and_modname']
  WithId_WithModname = definitions['with_id'].definitions['with_modname']
  WithId_WithIdAndModname = definitions['with_id'].definitions['with_id_and_modname']
  WithIdAndModname = definitions['with_id_and_modname']
  WithIdAndModname::WithModname = definitions['with_id_and_modname'].definitions['with_modname']
  WithIdAndModname::WithIdAndModname = definitions['with_id_and_modname'].definitions['with_id_and_modname']
end

describe 'JSI Schema Class, JSI Schema Module' do
  describe '.name/.name_from_ancestor, .inspect' do
    let(:actual) do
      schemas = Examples.schema.definitions.values.map { |s| s.definitions.values }.inject([], &:+)

      instances = [
        {},
        [],
        "",
        1,
        1.1,
        true,
        nil,
      ]

      actual_lines = []
      actual = schemas.each_with_index.map do |schema, i|
        schema_module = schema.jsi_schema_module
        instance = instances[i % instances.size]
        schema_instance_class = schema.new_jsi(instance).class

        actual_lines << "{"
        actual_lines << %Q(  "ptr": #{schema.jsi_ptr},)
        actual_lines << %Q(  "module.name_from_ancestor": #{schema_module.name_from_ancestor ? "%q(#{schema_module.name_from_ancestor})" : "nil"},)
        actual_lines << %Q(  "module.inspect": %q(#{schema_module.inspect}),)
        actual_lines << %Q(  "class.name": #{schema_instance_class.name ? "%q(#{schema_instance_class.name})" : "nil"},)
        actual_lines << %Q(  "class.inspect": %q(#{schema_instance_class.inspect}),)
        actual_lines << "},"

        {
          "ptr": schema.jsi_ptr,
          "module.name_from_ancestor": schema_module.name_from_ancestor,
          "module.inspect": schema_module.inspect,
          "class.name": schema_instance_class.name,
          "class.inspect": schema_instance_class.inspect,
        }
      end

      if ENV['JSI_TEST_REGEN']
        test = File.read(__FILE__).split("\n", -1)
        new_test = test[0...(line_a + 3)] + actual_lines.map { |l| ' ' * 8 + l } + test[(line_b - 3)..-1]
        if new_test != test
          File.write(__FILE__, new_test.join("\n"))
          skip("regenerated examples")
        end
      end

      actual
    end

    let(:line_a) { __LINE__ }
    let(:examples) do
      # GENERATED: run with env ENV['JSI_TEST_REGEN'] to regenerate
      [
        {
          "ptr": JSI::Ptr["definitions", "with_none", "definitions", "with_none"],
          "module.name_from_ancestor": %q(Examples.definitions["with_none"].definitions["with_none"]),
          "module.inspect": %q(Examples.definitions["with_none"].definitions["with_none"] (JSI Schema Module)),
          "class.name": %q(JSI::SchemaClasses::XExamples_definitions_with_none_definitions_with_none),
          "class.inspect": %q((JSI Schema Class: #/definitions/with_none/definitions/with_none)),
        },
        {
          "ptr": JSI::Ptr["definitions", "with_none", "definitions", "with_modname"],
          "module.name_from_ancestor": %q(Examples::WithNone_WithModname),
          "module.inspect": %q(Examples::WithNone_WithModname (JSI Schema Module)),
          "class.name": %q(JSI::SchemaClasses::XExamples__WithNone_WithModname),
          "class.inspect": %q((JSI Schema Class: Examples::WithNone_WithModname)),
        },
        {
          "ptr": JSI::Ptr["definitions", "with_none", "definitions", "with_id"],
          "module.name_from_ancestor": %q(Examples.definitions["with_none"].definitions["with_id"]),
          "module.inspect": %q(Examples.definitions["with_none"].definitions["with_id"] (JSI Schema Module)),
          "class.name": %q(JSI::SchemaClasses::XExamples_definitions_with_none_definitions_with_id),
          "class.inspect": %q((JSI Schema Class: tag:examples:with_none:with_id)),
        },
        {
          "ptr": JSI::Ptr["definitions", "with_none", "definitions", "with_id_and_modname"],
          "module.name_from_ancestor": %q(Examples::WithNone_WithIdAndModname),
          "module.inspect": %q(Examples::WithNone_WithIdAndModname (JSI Schema Module)),
          "class.name": %q(JSI::SchemaClasses::XExamples__WithNone_WithIdAndModname),
          "class.inspect": %q((JSI Schema Class: Examples::WithNone_WithIdAndModname (tag:examples:with_none:with_id_and_modname))),
        },
        {
          "ptr": JSI::Ptr["definitions", "with_modname", "definitions", "with_none"],
          "module.name_from_ancestor": %q(Examples::WithModname.definitions["with_none"]),
          "module.inspect": %q(Examples::WithModname.definitions["with_none"] (JSI Schema Module)),
          "class.name": %q(JSI::SchemaClasses::XExamples__WithModname_definitions_with_none),
          "class.inspect": %q((JSI Schema Class: #/definitions/with_modname/definitions/with_none)),
        },
        {
          "ptr": JSI::Ptr["definitions", "with_modname", "definitions", "with_modname"],
          "module.name_from_ancestor": %q(Examples::WithModname::WithModname),
          "module.inspect": %q(Examples::WithModname::WithModname (JSI Schema Module)),
          "class.name": %q(JSI::SchemaClasses::XExamples__WithModname__WithModname),
          "class.inspect": %q((JSI Schema Class: Examples::WithModname::WithModname)),
        },
        {
          "ptr": JSI::Ptr["definitions", "with_modname", "definitions", "with_id"],
          "module.name_from_ancestor": %q(Examples::WithModname.definitions["with_id"]),
          "module.inspect": %q(Examples::WithModname.definitions["with_id"] (JSI Schema Module)),
          "class.name": %q(JSI::SchemaClasses::XExamples__WithModname_definitions_with_id),
          "class.inspect": %q((JSI Schema Class: tag:examples:with_modname:with_id)),
        },
        {
          "ptr": JSI::Ptr["definitions", "with_modname", "definitions", "with_id_and_modname"],
          "module.name_from_ancestor": %q(Examples::WithModname::WithIdAndModname),
          "module.inspect": %q(Examples::WithModname::WithIdAndModname (JSI Schema Module)),
          "class.name": %q(JSI::SchemaClasses::XExamples__WithModname__WithIdAndModname),
          "class.inspect": %q((JSI Schema Class: Examples::WithModname::WithIdAndModname (tag:examples:with_modname:with_id_and_modname))),
        },
        {
          "ptr": JSI::Ptr["definitions", "with_id", "definitions", "with_none"],
          "module.name_from_ancestor": %q(Examples.definitions["with_id"].definitions["with_none"]),
          "module.inspect": %q(Examples.definitions["with_id"].definitions["with_none"] (JSI Schema Module)),
          "class.name": %q(JSI::SchemaClasses::XExamples_definitions_with_id_definitions_with_none),
          "class.inspect": %q((JSI Schema Class: tag:examples:with_id#/definitions/with_none)),
        },
        {
          "ptr": JSI::Ptr["definitions", "with_id", "definitions", "with_modname"],
          "module.name_from_ancestor": %q(Examples::WithId_WithModname),
          "module.inspect": %q(Examples::WithId_WithModname (JSI Schema Module)),
          "class.name": %q(JSI::SchemaClasses::XExamples__WithId_WithModname),
          "class.inspect": %q((JSI Schema Class: Examples::WithId_WithModname (tag:examples:with_id#/definitions/with_modname))),
        },
        {
          "ptr": JSI::Ptr["definitions", "with_id", "definitions", "with_id"],
          "module.name_from_ancestor": %q(Examples.definitions["with_id"].definitions["with_id"]),
          "module.inspect": %q(Examples.definitions["with_id"].definitions["with_id"] (JSI Schema Module)),
          "class.name": %q(JSI::SchemaClasses::XExamples_definitions_with_id_definitions_with_id),
          "class.inspect": %q((JSI Schema Class: tag:examples:with_id:with_id)),
        },
        {
          "ptr": JSI::Ptr["definitions", "with_id", "definitions", "with_id_and_modname"],
          "module.name_from_ancestor": %q(Examples::WithId_WithIdAndModname),
          "module.inspect": %q(Examples::WithId_WithIdAndModname (JSI Schema Module)),
          "class.name": %q(JSI::SchemaClasses::XExamples__WithId_WithIdAndModname),
          "class.inspect": %q((JSI Schema Class: Examples::WithId_WithIdAndModname (tag:examples:with_id:with_id_and_modname))),
        },
        {
          "ptr": JSI::Ptr["definitions", "with_id_and_modname", "definitions", "with_none"],
          "module.name_from_ancestor": %q(Examples::WithIdAndModname.definitions["with_none"]),
          "module.inspect": %q(Examples::WithIdAndModname.definitions["with_none"] (JSI Schema Module)),
          "class.name": %q(JSI::SchemaClasses::XExamples__WithIdAndModname_definitions_with_none),
          "class.inspect": %q((JSI Schema Class: tag:examples:with_id_and_modname#/definitions/with_none)),
        },
        {
          "ptr": JSI::Ptr["definitions", "with_id_and_modname", "definitions", "with_modname"],
          "module.name_from_ancestor": %q(Examples::WithIdAndModname::WithModname),
          "module.inspect": %q(Examples::WithIdAndModname::WithModname (JSI Schema Module)),
          "class.name": %q(JSI::SchemaClasses::XExamples__WithIdAndModname__WithModname),
          "class.inspect": %q((JSI Schema Class: Examples::WithIdAndModname::WithModname (tag:examples:with_id_and_modname#/definitions/with_modname))),
        },
        {
          "ptr": JSI::Ptr["definitions", "with_id_and_modname", "definitions", "with_id"],
          "module.name_from_ancestor": %q(Examples::WithIdAndModname.definitions["with_id"]),
          "module.inspect": %q(Examples::WithIdAndModname.definitions["with_id"] (JSI Schema Module)),
          "class.name": %q(JSI::SchemaClasses::XExamples__WithIdAndModname_definitions_with_id),
          "class.inspect": %q((JSI Schema Class: tag:examples:with_id_and_modname:with_id)),
        },
        {
          "ptr": JSI::Ptr["definitions", "with_id_and_modname", "definitions", "with_id_and_modname"],
          "module.name_from_ancestor": %q(Examples::WithIdAndModname::WithIdAndModname),
          "module.inspect": %q(Examples::WithIdAndModname::WithIdAndModname (JSI Schema Module)),
          "class.name": %q(JSI::SchemaClasses::XExamples__WithIdAndModname__WithIdAndModname),
          "class.inspect": %q((JSI Schema Class: Examples::WithIdAndModname::WithIdAndModname (tag:examples:with_id_and_modname:with_id_and_modname))),
        },
      ]
    end
    let(:line_b) { __LINE__ }

    it 'has expected name / inspect' do
      assert_equal(examples, actual)
    end
  end
end
