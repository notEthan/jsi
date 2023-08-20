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

      schemas.map do |schema|
        schema_module = schema.jsi_schema_module
        schema_instance_class = schema.new_jsi(nil).class

        {
          "ptr": schema.jsi_ptr,
          "module.name_from_ancestor": schema_module.name_from_ancestor,
          "module.inspect": schema_module.inspect,
          "class.name": schema_instance_class.name,
          "class.inspect": schema_instance_class.inspect,
        }
      end
    end

    let(:examples) do
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

    it 'has expected name / inspect' do
      assert_equal(examples, actual)
    end
  end
end
