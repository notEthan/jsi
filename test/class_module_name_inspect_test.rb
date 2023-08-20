require_relative 'test_helper'

Examples = JSI.new_schema_module(YAML.load(<<~YAML
  $schema: http://json-schema.org/draft-07/schema
  definitions:
    with_none:
      definitions:
        with_none:
          title: with_none subschema without id or modname
        with_none_multi:
          title: with_none subschema without id or modname with multiple schemas
          allOf:
            - title: no id
            - title: id
              $id: "tag:examples:with_none:with_none_multi:with_id"
            - title: modname
        with_modname:
          title: with_none subschema with modname
        with_modname_multi:
          title: with_none subschema with modname with multiple schemas
          allOf:
            - title: no id
            - title: id
              $id: "tag:examples:with_none:with_modname_multi:with_id"
            - title: modname
        with_id:
          $id: tag:examples:with_none:with_id
          title: with_none subschema with id
        with_id_multi:
          $id: tag:examples:with_none:with_id_multi
          title: with_none subschema with id with multiple schemas
          allOf:
            - title: no id
            - title: id
              $id: "tag:examples:with_none:with_id_multi:with_id"
            - title: modname
        with_id_and_modname:
          $id: tag:examples:with_none:with_id_and_modname
          title: with_none subschema with id and modname
        with_id_and_modname_multi:
          $id: tag:examples:with_none:with_id_and_modname_multi
          title: with_none subschema with id and modname with multiple schemas
          allOf:
            - title: no id
            - title: id
              $id: "tag:examples:with_none:with_id_and_modname_multi:with_id"
            - title: modname
    with_modname:
      definitions:
        with_none:
          title: with_modname subschema without id or modname
        with_none_multi:
          title: with_modname subschema without id or modname with multiple schemas
          allOf:
            - title: no id
            - title: id
              $id: "tag:examples:with_modname:with_none_multi:with_id"
            - title: modname
        with_modname:
          title: with_modname subschema with modname
        with_modname_multi:
          title: with_modname subschema with modname with multiple schemas
          allOf:
            - title: no id
            - title: id
              $id: "tag:examples:with_modname:with_modname_multi:with_id"
            - title: modname
        with_id:
          $id: tag:examples:with_modname:with_id
          title: with_modname subschema with id
        with_id_multi:
          $id: tag:examples:with_modname:with_id_multi
          title: with_modname subschema with id with multiple schemas
          allOf:
            - title: no id
            - title: id
              $id: "tag:examples:with_modname:with_id_multi:with_id"
            - title: modname
        with_id_and_modname:
          $id: tag:examples:with_modname:with_id_and_modname
          title: with_modname subschema with id and modname
        with_id_and_modname_multi:
          $id: tag:examples:with_modname:with_id_and_modname_multi
          title: with_modname subschema with id and modname with multiple schemas
          allOf:
            - title: no id
            - title: id
              $id: "tag:examples:with_modname:with_id_and_modname_multi:with_id"
            - title: modname
    with_id:
      $id: tag:examples:with_id
      definitions:
        with_none:
          title: with_id subschema without id or modname
        with_none_multi:
          title: with_id subschema without id or modname with multiple schemas
          allOf:
            - title: no id
            - title: id
              $id: "tag:examples:with_id:with_none_multi:with_id"
            - title: modname
        with_modname:
          title: with_id subschema with modname
        with_modname_multi:
          title: with_id subschema with modname with multiple schemas
          allOf:
            - title: no id
            - title: id
              $id: "tag:examples:with_id:with_modname_multi:with_id"
            - title: modname
        with_id:
          $id: tag:examples:with_id:with_id
          title: with_id subschema with id
        with_id_multi:
          $id: tag:examples:with_id:with_id_multi
          title: with_id subschema with id with multiple schemas
          allOf:
            - title: no id
            - title: id
              $id: "tag:examples:with_id:with_id_multi:with_id"
            - title: modname
        with_id_and_modname:
          $id: tag:examples:with_id:with_id_and_modname
          title: with_id subschema with id and modname
        with_id_and_modname_multi:
          $id: tag:examples:with_id:with_id_and_modname_multi
          title: with_id subschema with id and modname with multiple schemas
          allOf:
            - title: no id
            - title: id
              $id: "tag:examples:with_id:with_id_and_modname_multi:with_id"
            - title: modname
    with_id_and_modname:
      $id: tag:examples:with_id_and_modname
      definitions:
        with_none:
          title: with_id_and_modname subschema without id or modname
        with_none_multi:
          title: with_id_and_modname subschema without id or modname with multiple schemas
          allOf:
            - title: no id
            - title: id
              $id: "tag:examples:with_id_and_modname:with_none_multi:with_id"
            - title: modname
        with_modname:
          title: with_id_and_modname subschema with modname
        with_modname_multi:
          title: with_id_and_modname subschema with modname with multiple schemas
          allOf:
            - title: no id
            - title: id
              $id: "tag:examples:with_id_and_modname:with_modname_multi:with_id"
            - title: modname
        with_id:
          $id: tag:examples:with_id_and_modname:with_id
          title: with_id_and_modname subschema with id
        with_id_multi:
          $id: tag:examples:with_id_and_modname:with_id_multi
          title: with_id_and_modname subschema with id with multiple schemas
          allOf:
            - title: no id
            - title: id
              $id: "tag:examples:with_id_and_modname:with_id_multi:with_id"
            - title: modname
        with_id_and_modname:
          $id: tag:examples:with_id_and_modname:with_id_and_modname
          title: with_id_and_modname subschema with id and modname
        with_id_and_modname_multi:
          $id: tag:examples:with_id_and_modname:with_id_and_modname_multi
          title: with_id_and_modname subschema with id and modname with multiple schemas
          allOf:
            - title: no id
            - title: id
              $id: "tag:examples:with_id_and_modname:with_id_and_modname_multi:with_id"
            - title: modname
  YAML
))

module Examples
  WithNone_WithModname = definitions['with_none'].definitions['with_modname']
  WithNone_WithModnameMulti = definitions['with_none'].definitions['with_modname_multi']
  WithNone_WithIdAndModname = definitions['with_none'].definitions['with_id_and_modname']
  WithNone_WithIdAndModnameMulti = definitions['with_none'].definitions['with_id_and_modname_multi']
  WithModname = definitions['with_modname']
  WithModname::WithModname = definitions['with_modname'].definitions['with_modname']
  WithModname::WithModnameMulti = definitions['with_modname'].definitions['with_modname_multi']
  WithModname::WithIdAndModname = definitions['with_modname'].definitions['with_id_and_modname']
  WithModname::WithIdAndModnameMulti = definitions['with_modname'].definitions['with_id_and_modname_multi']
  WithId_WithModname = definitions['with_id'].definitions['with_modname']
  WithId_WithModnameMulti = definitions['with_id'].definitions['with_modname_multi']
  WithId_WithIdAndModname = definitions['with_id'].definitions['with_id_and_modname']
  WithId_WithIdAndModnameMulti = definitions['with_id'].definitions['with_id_and_modname_multi']
  WithIdAndModname = definitions['with_id_and_modname']
  WithIdAndModname::WithModname = definitions['with_id_and_modname'].definitions['with_modname']
  WithIdAndModname::WithModnameMulti = definitions['with_id_and_modname'].definitions['with_modname_multi']
  WithIdAndModname::WithIdAndModname = definitions['with_id_and_modname'].definitions['with_id_and_modname']
  WithIdAndModname::WithIdAndModnameMulti = definitions['with_id_and_modname'].definitions['with_id_and_modname_multi']

  WithNone_WithNoneMulti_allOfmodname = definitions['with_none'].definitions['with_none_multi'].allOf[2]
  WithNone_WithModnameMulti::AllOfModname = definitions['with_none'].definitions['with_modname_multi'].allOf[2]
  WithNone_WithIdMulti_allOfmodname = definitions['with_none'].definitions['with_id_multi'].allOf[2]
  WithNone_WithIdAndModnameMulti::AllOfModname = definitions['with_none'].definitions['with_id_and_modname_multi'].allOf[2]
  WithModname::WithNoneMulti_allOfModname = definitions['with_modname'].definitions['with_none_multi'].allOf[2]
  WithModname::WithModnameMulti_allOfModname = definitions['with_modname'].definitions['with_modname_multi'].allOf[2]
  WithModname::WithIdMulti_allOfModname = definitions['with_modname'].definitions['with_id_multi'].allOf[2]
  WithModname::WithIdAndModnameMulti_allOfModname = definitions['with_modname'].definitions['with_id_and_modname_multi'].allOf[2]
  WithId_WithNoneMulti_allOfModname = definitions['with_id'].definitions['with_none_multi'].allOf[2]
  WithId_WithModnameMulti::AllOfModname = definitions['with_id'].definitions['with_modname_multi'].allOf[2]
  WithId_WithIdMulti_allOfModname = definitions['with_id'].definitions['with_id_multi'].allOf[2]
  WithId_WithIdAndModnameMulti::AllOfModname = definitions['with_id'].definitions['with_id_and_modname_multi'].allOf[2]
  WithIdAndModname::WithNoneMulti_allOfModname = definitions['with_id_and_modname'].definitions['with_none_multi'].allOf[2]
  WithIdAndModname::WithModnameMulti::AllOfModname = definitions['with_id_and_modname'].definitions['with_modname_multi'].allOf[2]
  WithIdAndModname::WithIdMulti_allOfModname = definitions['with_id_and_modname'].definitions['with_id_multi'].allOf[2]
  WithIdAndModname::WithIdAndModnameMulti::AllOfModname = definitions['with_id_and_modname'].definitions['with_id_and_modname_multi'].allOf[2]
end

$examples_anon = JSI.new_schema_module(YAML.load(<<~YAML
  $schema: http://json-schema.org/draft-07/schema
  definitions:
    with_none:
      definitions:
        with_none:
          title: with_none subschema without id or modname
        with_none_multi:
          title: with_none subschema without id or modname with multiple schemas
          allOf:
            - title: no id
            - title: id
              $id: "tag:examples_anon:with_none:with_none_multi:with_id"
        with_id:
          $id: tag:examples_anon:with_none:with_id
          title: with_none subschema with id
        with_id_multi:
          $id: tag:examples_anon:with_none:with_id_multi
          title: with_none subschema with id with multiple schemas
          allOf:
            - title: no id
            - title: id
              $id: "tag:examples_anon:with_none:with_id_multi:with_id"
    with_id:
      $id: tag:examples_anon:with_id
      definitions:
        with_none:
          title: with_id subschema without id or modname
        with_none_multi:
          title: with_id subschema without id or modname with multiple schemas
          allOf:
            - title: no id
            - title: id
              $id: "tag:examples_anon:with_id:with_none_multi:with_id"
        with_id:
          $id: tag:examples_anon:with_id:with_id
          title: with_id subschema with id
        with_id_multi:
          $id: tag:examples_anon:with_id:with_id_multi
          title: with_id subschema with id with multiple schemas
          allOf:
            - title: no id
            - title: id
              $id: "tag:examples_anon:with_id:with_id_multi:with_id"
  YAML
))

describe 'JSI Schema Class, JSI Schema Module' do
  describe '.name/.name_from_ancestor, .inspect' do
    let(:actual) do
      schemas = (Examples.schema.definitions.values + $examples_anon.schema.definitions.values).map { |s| s.definitions.values }.inject([], &:+)

      ids = Hash.new do |h, id|
        # kind of a silly thing to map unpredictable generated ids consistently to a unique replacement.
        # this is only used for one generated id at the moment. still good to ensure.
        h[id] = (h.size % 36**4).to_s(36).rjust(4, '0').upcase
      end

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
        schema_instance_class_name = schema_instance_class.name.gsub(/(_|:)X([0-9A-Z]{4})(_|:|$)/) { $1 + 'X' + ids[$2] + $3 }

        actual_lines << "{"
        actual_lines << %Q(  "ptr": #{schema.jsi_ptr},)
        actual_lines << %Q(  "module.name_from_ancestor": #{schema_module.name_from_ancestor ? "%q(#{schema_module.name_from_ancestor})" : "nil"},)
        actual_lines << %Q(  "module.inspect": %q(#{schema_module.inspect}),)
        actual_lines << %Q(  "class.name": #{schema_instance_class_name ? "%q(#{schema_instance_class_name})" : "nil"},)
        actual_lines << %Q(  "class.inspect": %q(#{schema_instance_class.inspect}),)
        actual_lines << "},"

        {
          "ptr": schema.jsi_ptr,
          "module.name_from_ancestor": schema_module.name_from_ancestor,
          "module.inspect": schema_module.inspect,
          "class.name": schema_instance_class_name,
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
          "class.name": %q(JSI::SchemaClasses::XExamples_definitions_with_none_definitions_with_none__HashNode),
          "class.inspect": %q((JSI Schema Class: Examples.definitions["with_none"].definitions["with_none"])),
        },
        {
          "ptr": JSI::Ptr["definitions", "with_none", "definitions", "with_none_multi"],
          "module.name_from_ancestor": %q(Examples.definitions["with_none"].definitions["with_none_multi"]),
          "module.inspect": %q(Examples.definitions["with_none"].definitions["with_none_multi"] (JSI Schema Module)),
          "class.name": %q(JSI::SchemaClasses::XExamples_WithNone_WithNoneMulti_allOfmodname__XExamples_definitions_with_none_definitions_with_none_multi__XExamples_definitions_with_none_definitions_with_none_multi_allOf_0__XExamples_definitions_with_none_definitions_with_none_multi_allOf_1__ArrayNode),
          "class.inspect": %q((JSI Schema Class: Examples.definitions["with_none"].definitions["with_none_multi"] + Examples.definitions["with_none"].definitions["with_none_multi"].allOf[0] + Examples.definitions["with_none"].definitions["with_none_multi"].allOf[1] <tag:examples:with_none:with_none_multi:with_id> + Examples::WithNone_WithNoneMulti_allOfmodname)),
        },
        {
          "ptr": JSI::Ptr["definitions", "with_none", "definitions", "with_modname"],
          "module.name_from_ancestor": %q(Examples::WithNone_WithModname),
          "module.inspect": %q(Examples::WithNone_WithModname (JSI Schema Module)),
          "class.name": %q(JSI::SchemaClasses::XExamples_WithNone_WithModname__StringNode),
          "class.inspect": %q((JSI Schema Class: Examples::WithNone_WithModname)),
        },
        {
          "ptr": JSI::Ptr["definitions", "with_none", "definitions", "with_modname_multi"],
          "module.name_from_ancestor": %q(Examples::WithNone_WithModnameMulti),
          "module.inspect": %q(Examples::WithNone_WithModnameMulti (JSI Schema Module)),
          "class.name": %q(JSI::SchemaClasses::XExamples_WithNone_WithModnameMulti__XExamples_WithNone_WithModnameMulti_AllOfModname__XExamples_WithNone_WithModnameMulti_allOf_0__XExamples_WithNone_WithModnameMulti_allOf_1),
          "class.inspect": %q((JSI Schema Class: Examples::WithNone_WithModnameMulti + Examples::WithNone_WithModnameMulti.allOf[0] + Examples::WithNone_WithModnameMulti.allOf[1] <tag:examples:with_none:with_modname_multi:with_id> + Examples::WithNone_WithModnameMulti::AllOfModname)),
        },
        {
          "ptr": JSI::Ptr["definitions", "with_none", "definitions", "with_id"],
          "module.name_from_ancestor": %q(Examples.definitions["with_none"].definitions["with_id"]),
          "module.inspect": %q(Examples.definitions["with_none"].definitions["with_id"] <tag:examples:with_none:with_id> (JSI Schema Module)),
          "class.name": %q(JSI::SchemaClasses::XExamples_definitions_with_none_definitions_with_id),
          "class.inspect": %q((JSI Schema Class: Examples.definitions["with_none"].definitions["with_id"] <tag:examples:with_none:with_id>)),
        },
        {
          "ptr": JSI::Ptr["definitions", "with_none", "definitions", "with_id_multi"],
          "module.name_from_ancestor": %q(Examples.definitions["with_none"].definitions["with_id_multi"]),
          "module.inspect": %q(Examples.definitions["with_none"].definitions["with_id_multi"] <tag:examples:with_none:with_id_multi> (JSI Schema Module)),
          "class.name": %q(JSI::SchemaClasses::XExamples_WithNone_WithIdMulti_allOfmodname__XExamples_definitions_with_none_definitions_with_id_multi__XExamples_definitions_with_none_definitions_with_id_multi_allOf_0__XExamples_definitions_with_none_definitions_with_id_multi_allOf_1),
          "class.inspect": %q((JSI Schema Class: Examples.definitions["with_none"].definitions["with_id_multi"] <tag:examples:with_none:with_id_multi> + Examples.definitions["with_none"].definitions["with_id_multi"].allOf[0] + Examples.definitions["with_none"].definitions["with_id_multi"].allOf[1] <tag:examples:with_none:with_id_multi:with_id> + Examples::WithNone_WithIdMulti_allOfmodname)),
        },
        {
          "ptr": JSI::Ptr["definitions", "with_none", "definitions", "with_id_and_modname"],
          "module.name_from_ancestor": %q(Examples::WithNone_WithIdAndModname),
          "module.inspect": %q(Examples::WithNone_WithIdAndModname <tag:examples:with_none:with_id_and_modname> (JSI Schema Module)),
          "class.name": %q(JSI::SchemaClasses::XExamples_WithNone_WithIdAndModname),
          "class.inspect": %q((JSI Schema Class: Examples::WithNone_WithIdAndModname <tag:examples:with_none:with_id_and_modname>)),
        },
        {
          "ptr": JSI::Ptr["definitions", "with_none", "definitions", "with_id_and_modname_multi"],
          "module.name_from_ancestor": %q(Examples::WithNone_WithIdAndModnameMulti),
          "module.inspect": %q(Examples::WithNone_WithIdAndModnameMulti <tag:examples:with_none:with_id_and_modname_multi> (JSI Schema Module)),
          "class.name": %q(JSI::SchemaClasses::XExamples_WithNone_WithIdAndModnameMulti__XExamples_WithNone_WithIdAndModnameMulti_AllOfModname__XExamples_WithNone_WithIdAndModnameMulti_allOf_0__XExamples_WithNone_WithIdAndModnameMulti_allOf_1__HashNode),
          "class.inspect": %q((JSI Schema Class: Examples::WithNone_WithIdAndModnameMulti <tag:examples:with_none:with_id_and_modname_multi> + Examples::WithNone_WithIdAndModnameMulti.allOf[0] + Examples::WithNone_WithIdAndModnameMulti.allOf[1] <tag:examples:with_none:with_id_and_modname_multi:with_id> + Examples::WithNone_WithIdAndModnameMulti::AllOfModname)),
        },
        {
          "ptr": JSI::Ptr["definitions", "with_modname", "definitions", "with_none"],
          "module.name_from_ancestor": %q(Examples::WithModname.definitions["with_none"]),
          "module.inspect": %q(Examples::WithModname.definitions["with_none"] (JSI Schema Module)),
          "class.name": %q(JSI::SchemaClasses::XExamples_WithModname_definitions_with_none__ArrayNode),
          "class.inspect": %q((JSI Schema Class: Examples::WithModname.definitions["with_none"])),
        },
        {
          "ptr": JSI::Ptr["definitions", "with_modname", "definitions", "with_none_multi"],
          "module.name_from_ancestor": %q(Examples::WithModname.definitions["with_none_multi"]),
          "module.inspect": %q(Examples::WithModname.definitions["with_none_multi"] (JSI Schema Module)),
          "class.name": %q(JSI::SchemaClasses::XExamples_WithModname_WithNoneMulti_allOfModname__XExamples_WithModname_definitions_with_none_multi__XExamples_WithModname_definitions_with_none_multi_allOf_0__XExamples_WithModname_definitions_with_none_multi_allOf_1__StringNode),
          "class.inspect": %q((JSI Schema Class: Examples::WithModname.definitions["with_none_multi"] + Examples::WithModname.definitions["with_none_multi"].allOf[0] + Examples::WithModname.definitions["with_none_multi"].allOf[1] <tag:examples:with_modname:with_none_multi:with_id> + Examples::WithModname::WithNoneMulti_allOfModname)),
        },
        {
          "ptr": JSI::Ptr["definitions", "with_modname", "definitions", "with_modname"],
          "module.name_from_ancestor": %q(Examples::WithModname::WithModname),
          "module.inspect": %q(Examples::WithModname::WithModname (JSI Schema Module)),
          "class.name": %q(JSI::SchemaClasses::XExamples_WithModname_WithModname),
          "class.inspect": %q((JSI Schema Class: Examples::WithModname::WithModname)),
        },
        {
          "ptr": JSI::Ptr["definitions", "with_modname", "definitions", "with_modname_multi"],
          "module.name_from_ancestor": %q(Examples::WithModname::WithModnameMulti),
          "module.inspect": %q(Examples::WithModname::WithModnameMulti (JSI Schema Module)),
          "class.name": %q(JSI::SchemaClasses::XExamples_WithModname_WithModnameMulti__XExamples_WithModname_WithModnameMulti_allOfModname__XExamples_WithModname_WithModnameMulti_allOf_0__XExamples_WithModname_WithModnameMulti_allOf_1),
          "class.inspect": %q((JSI Schema Class: Examples::WithModname::WithModnameMulti + Examples::WithModname::WithModnameMulti.allOf[0] + Examples::WithModname::WithModnameMulti.allOf[1] <tag:examples:with_modname:with_modname_multi:with_id> + Examples::WithModname::WithModnameMulti_allOfModname)),
        },
        {
          "ptr": JSI::Ptr["definitions", "with_modname", "definitions", "with_id"],
          "module.name_from_ancestor": %q(Examples::WithModname.definitions["with_id"]),
          "module.inspect": %q(Examples::WithModname.definitions["with_id"] <tag:examples:with_modname:with_id> (JSI Schema Module)),
          "class.name": %q(JSI::SchemaClasses::XExamples_WithModname_definitions_with_id),
          "class.inspect": %q((JSI Schema Class: Examples::WithModname.definitions["with_id"] <tag:examples:with_modname:with_id>)),
        },
        {
          "ptr": JSI::Ptr["definitions", "with_modname", "definitions", "with_id_multi"],
          "module.name_from_ancestor": %q(Examples::WithModname.definitions["with_id_multi"]),
          "module.inspect": %q(Examples::WithModname.definitions["with_id_multi"] <tag:examples:with_modname:with_id_multi> (JSI Schema Module)),
          "class.name": %q(JSI::SchemaClasses::XExamples_WithModname_WithIdMulti_allOfModname__XExamples_WithModname_definitions_with_id_multi__XExamples_WithModname_definitions_with_id_multi_allOf_0__XExamples_WithModname_definitions_with_id_multi_allOf_1),
          "class.inspect": %q((JSI Schema Class: Examples::WithModname.definitions["with_id_multi"] <tag:examples:with_modname:with_id_multi> + Examples::WithModname.definitions["with_id_multi"].allOf[0] + Examples::WithModname.definitions["with_id_multi"].allOf[1] <tag:examples:with_modname:with_id_multi:with_id> + Examples::WithModname::WithIdMulti_allOfModname)),
        },
        {
          "ptr": JSI::Ptr["definitions", "with_modname", "definitions", "with_id_and_modname"],
          "module.name_from_ancestor": %q(Examples::WithModname::WithIdAndModname),
          "module.inspect": %q(Examples::WithModname::WithIdAndModname <tag:examples:with_modname:with_id_and_modname> (JSI Schema Module)),
          "class.name": %q(JSI::SchemaClasses::XExamples_WithModname_WithIdAndModname__HashNode),
          "class.inspect": %q((JSI Schema Class: Examples::WithModname::WithIdAndModname <tag:examples:with_modname:with_id_and_modname>)),
        },
        {
          "ptr": JSI::Ptr["definitions", "with_modname", "definitions", "with_id_and_modname_multi"],
          "module.name_from_ancestor": %q(Examples::WithModname::WithIdAndModnameMulti),
          "module.inspect": %q(Examples::WithModname::WithIdAndModnameMulti <tag:examples:with_modname:with_id_and_modname_multi> (JSI Schema Module)),
          "class.name": %q(JSI::SchemaClasses::XExamples_WithModname_WithIdAndModnameMulti__XExamples_WithModname_WithIdAndModnameMulti_allOfModname__XExamples_WithModname_WithIdAndModnameMulti_allOf_0__XExamples_WithModname_WithIdAndModnameMulti_allOf_1__ArrayNode),
          "class.inspect": %q((JSI Schema Class: Examples::WithModname::WithIdAndModnameMulti <tag:examples:with_modname:with_id_and_modname_multi> + Examples::WithModname::WithIdAndModnameMulti.allOf[0] + Examples::WithModname::WithIdAndModnameMulti.allOf[1] <tag:examples:with_modname:with_id_and_modname_multi:with_id> + Examples::WithModname::WithIdAndModnameMulti_allOfModname)),
        },
        {
          "ptr": JSI::Ptr["definitions", "with_id", "definitions", "with_none"],
          "module.name_from_ancestor": %q(Examples.definitions["with_id"].definitions["with_none"]),
          "module.inspect": %q(Examples.definitions["with_id"].definitions["with_none"] (JSI Schema Module)),
          "class.name": %q(JSI::SchemaClasses::XExamples_definitions_with_id_definitions_with_none__StringNode),
          "class.inspect": %q((JSI Schema Class: Examples.definitions["with_id"].definitions["with_none"])),
        },
        {
          "ptr": JSI::Ptr["definitions", "with_id", "definitions", "with_none_multi"],
          "module.name_from_ancestor": %q(Examples.definitions["with_id"].definitions["with_none_multi"]),
          "module.inspect": %q(Examples.definitions["with_id"].definitions["with_none_multi"] (JSI Schema Module)),
          "class.name": %q(JSI::SchemaClasses::XExamples_WithId_WithNoneMulti_allOfModname__XExamples_definitions_with_id_definitions_with_none_multi__XExamples_definitions_with_id_definitions_with_none_multi_allOf_0__XExamples_definitions_with_id_definitions_with_none_multi_allOf_1),
          "class.inspect": %q((JSI Schema Class: Examples.definitions["with_id"].definitions["with_none_multi"] + Examples.definitions["with_id"].definitions["with_none_multi"].allOf[0] + Examples.definitions["with_id"].definitions["with_none_multi"].allOf[1] <tag:examples:with_id:with_none_multi:with_id> + Examples::WithId_WithNoneMulti_allOfModname)),
        },
        {
          "ptr": JSI::Ptr["definitions", "with_id", "definitions", "with_modname"],
          "module.name_from_ancestor": %q(Examples::WithId_WithModname),
          "module.inspect": %q(Examples::WithId_WithModname (JSI Schema Module)),
          "class.name": %q(JSI::SchemaClasses::XExamples_WithId_WithModname),
          "class.inspect": %q((JSI Schema Class: Examples::WithId_WithModname)),
        },
        {
          "ptr": JSI::Ptr["definitions", "with_id", "definitions", "with_modname_multi"],
          "module.name_from_ancestor": %q(Examples::WithId_WithModnameMulti),
          "module.inspect": %q(Examples::WithId_WithModnameMulti (JSI Schema Module)),
          "class.name": %q(JSI::SchemaClasses::XExamples_WithId_WithModnameMulti__XExamples_WithId_WithModnameMulti_AllOfModname__XExamples_WithId_WithModnameMulti_allOf_0__XExamples_WithId_WithModnameMulti_allOf_1),
          "class.inspect": %q((JSI Schema Class: Examples::WithId_WithModnameMulti + Examples::WithId_WithModnameMulti.allOf[0] + Examples::WithId_WithModnameMulti.allOf[1] <tag:examples:with_id:with_modname_multi:with_id> + Examples::WithId_WithModnameMulti::AllOfModname)),
        },
        {
          "ptr": JSI::Ptr["definitions", "with_id", "definitions", "with_id"],
          "module.name_from_ancestor": %q(Examples.definitions["with_id"].definitions["with_id"]),
          "module.inspect": %q(Examples.definitions["with_id"].definitions["with_id"] <tag:examples:with_id:with_id> (JSI Schema Module)),
          "class.name": %q(JSI::SchemaClasses::XExamples_definitions_with_id_definitions_with_id),
          "class.inspect": %q((JSI Schema Class: Examples.definitions["with_id"].definitions["with_id"] <tag:examples:with_id:with_id>)),
        },
        {
          "ptr": JSI::Ptr["definitions", "with_id", "definitions", "with_id_multi"],
          "module.name_from_ancestor": %q(Examples.definitions["with_id"].definitions["with_id_multi"]),
          "module.inspect": %q(Examples.definitions["with_id"].definitions["with_id_multi"] <tag:examples:with_id:with_id_multi> (JSI Schema Module)),
          "class.name": %q(JSI::SchemaClasses::XExamples_WithId_WithIdMulti_allOfModname__XExamples_definitions_with_id_definitions_with_id_multi__XExamples_definitions_with_id_definitions_with_id_multi_allOf_0__XExamples_definitions_with_id_definitions_with_id_multi_allOf_1__HashNode),
          "class.inspect": %q((JSI Schema Class: Examples.definitions["with_id"].definitions["with_id_multi"] <tag:examples:with_id:with_id_multi> + Examples.definitions["with_id"].definitions["with_id_multi"].allOf[0] + Examples.definitions["with_id"].definitions["with_id_multi"].allOf[1] <tag:examples:with_id:with_id_multi:with_id> + Examples::WithId_WithIdMulti_allOfModname)),
        },
        {
          "ptr": JSI::Ptr["definitions", "with_id", "definitions", "with_id_and_modname"],
          "module.name_from_ancestor": %q(Examples::WithId_WithIdAndModname),
          "module.inspect": %q(Examples::WithId_WithIdAndModname <tag:examples:with_id:with_id_and_modname> (JSI Schema Module)),
          "class.name": %q(JSI::SchemaClasses::XExamples_WithId_WithIdAndModname__ArrayNode),
          "class.inspect": %q((JSI Schema Class: Examples::WithId_WithIdAndModname <tag:examples:with_id:with_id_and_modname>)),
        },
        {
          "ptr": JSI::Ptr["definitions", "with_id", "definitions", "with_id_and_modname_multi"],
          "module.name_from_ancestor": %q(Examples::WithId_WithIdAndModnameMulti),
          "module.inspect": %q(Examples::WithId_WithIdAndModnameMulti <tag:examples:with_id:with_id_and_modname_multi> (JSI Schema Module)),
          "class.name": %q(JSI::SchemaClasses::XExamples_WithId_WithIdAndModnameMulti__XExamples_WithId_WithIdAndModnameMulti_AllOfModname__XExamples_WithId_WithIdAndModnameMulti_allOf_0__XExamples_WithId_WithIdAndModnameMulti_allOf_1__StringNode),
          "class.inspect": %q((JSI Schema Class: Examples::WithId_WithIdAndModnameMulti <tag:examples:with_id:with_id_and_modname_multi> + Examples::WithId_WithIdAndModnameMulti.allOf[0] + Examples::WithId_WithIdAndModnameMulti.allOf[1] <tag:examples:with_id:with_id_and_modname_multi:with_id> + Examples::WithId_WithIdAndModnameMulti::AllOfModname)),
        },
        {
          "ptr": JSI::Ptr["definitions", "with_id_and_modname", "definitions", "with_none"],
          "module.name_from_ancestor": %q(Examples::WithIdAndModname.definitions["with_none"]),
          "module.inspect": %q(Examples::WithIdAndModname.definitions["with_none"] (JSI Schema Module)),
          "class.name": %q(JSI::SchemaClasses::XExamples_WithIdAndModname_definitions_with_none),
          "class.inspect": %q((JSI Schema Class: Examples::WithIdAndModname.definitions["with_none"])),
        },
        {
          "ptr": JSI::Ptr["definitions", "with_id_and_modname", "definitions", "with_none_multi"],
          "module.name_from_ancestor": %q(Examples::WithIdAndModname.definitions["with_none_multi"]),
          "module.inspect": %q(Examples::WithIdAndModname.definitions["with_none_multi"] (JSI Schema Module)),
          "class.name": %q(JSI::SchemaClasses::XExamples_WithIdAndModname_WithNoneMulti_allOfModname__XExamples_WithIdAndModname_definitions_with_none_multi__XExamples_WithIdAndModname_definitions_with_none_multi_allOf_0__XExamples_WithIdAndModname_definitions_with_none_multi_allOf_1),
          "class.inspect": %q((JSI Schema Class: Examples::WithIdAndModname.definitions["with_none_multi"] + Examples::WithIdAndModname.definitions["with_none_multi"].allOf[0] + Examples::WithIdAndModname.definitions["with_none_multi"].allOf[1] <tag:examples:with_id_and_modname:with_none_multi:with_id> + Examples::WithIdAndModname::WithNoneMulti_allOfModname)),
        },
        {
          "ptr": JSI::Ptr["definitions", "with_id_and_modname", "definitions", "with_modname"],
          "module.name_from_ancestor": %q(Examples::WithIdAndModname::WithModname),
          "module.inspect": %q(Examples::WithIdAndModname::WithModname (JSI Schema Module)),
          "class.name": %q(JSI::SchemaClasses::XExamples_WithIdAndModname_WithModname),
          "class.inspect": %q((JSI Schema Class: Examples::WithIdAndModname::WithModname)),
        },
        {
          "ptr": JSI::Ptr["definitions", "with_id_and_modname", "definitions", "with_modname_multi"],
          "module.name_from_ancestor": %q(Examples::WithIdAndModname::WithModnameMulti),
          "module.inspect": %q(Examples::WithIdAndModname::WithModnameMulti (JSI Schema Module)),
          "class.name": %q(JSI::SchemaClasses::XExamples_WithIdAndModname_WithModnameMulti__XExamples_WithIdAndModname_WithModnameMulti_AllOfModname__XExamples_WithIdAndModname_WithModnameMulti_allOf_0__XExamples_WithIdAndModname_WithModnameMulti_allOf_1),
          "class.inspect": %q((JSI Schema Class: Examples::WithIdAndModname::WithModnameMulti + Examples::WithIdAndModname::WithModnameMulti.allOf[0] + Examples::WithIdAndModname::WithModnameMulti.allOf[1] <tag:examples:with_id_and_modname:with_modname_multi:with_id> + Examples::WithIdAndModname::WithModnameMulti::AllOfModname)),
        },
        {
          "ptr": JSI::Ptr["definitions", "with_id_and_modname", "definitions", "with_id"],
          "module.name_from_ancestor": %q(Examples::WithIdAndModname.definitions["with_id"]),
          "module.inspect": %q(Examples::WithIdAndModname.definitions["with_id"] <tag:examples:with_id_and_modname:with_id> (JSI Schema Module)),
          "class.name": %q(JSI::SchemaClasses::XExamples_WithIdAndModname_definitions_with_id__HashNode),
          "class.inspect": %q((JSI Schema Class: Examples::WithIdAndModname.definitions["with_id"] <tag:examples:with_id_and_modname:with_id>)),
        },
        {
          "ptr": JSI::Ptr["definitions", "with_id_and_modname", "definitions", "with_id_multi"],
          "module.name_from_ancestor": %q(Examples::WithIdAndModname.definitions["with_id_multi"]),
          "module.inspect": %q(Examples::WithIdAndModname.definitions["with_id_multi"] <tag:examples:with_id_and_modname:with_id_multi> (JSI Schema Module)),
          "class.name": %q(JSI::SchemaClasses::XExamples_WithIdAndModname_WithIdMulti_allOfModname__XExamples_WithIdAndModname_definitions_with_id_multi__XExamples_WithIdAndModname_definitions_with_id_multi_allOf_0__XExamples_WithIdAndModname_definitions_with_id_multi_allOf_1__ArrayNode),
          "class.inspect": %q((JSI Schema Class: Examples::WithIdAndModname.definitions["with_id_multi"] <tag:examples:with_id_and_modname:with_id_multi> + Examples::WithIdAndModname.definitions["with_id_multi"].allOf[0] + Examples::WithIdAndModname.definitions["with_id_multi"].allOf[1] <tag:examples:with_id_and_modname:with_id_multi:with_id> + Examples::WithIdAndModname::WithIdMulti_allOfModname)),
        },
        {
          "ptr": JSI::Ptr["definitions", "with_id_and_modname", "definitions", "with_id_and_modname"],
          "module.name_from_ancestor": %q(Examples::WithIdAndModname::WithIdAndModname),
          "module.inspect": %q(Examples::WithIdAndModname::WithIdAndModname <tag:examples:with_id_and_modname:with_id_and_modname> (JSI Schema Module)),
          "class.name": %q(JSI::SchemaClasses::XExamples_WithIdAndModname_WithIdAndModname__StringNode),
          "class.inspect": %q((JSI Schema Class: Examples::WithIdAndModname::WithIdAndModname <tag:examples:with_id_and_modname:with_id_and_modname>)),
        },
        {
          "ptr": JSI::Ptr["definitions", "with_id_and_modname", "definitions", "with_id_and_modname_multi"],
          "module.name_from_ancestor": %q(Examples::WithIdAndModname::WithIdAndModnameMulti),
          "module.inspect": %q(Examples::WithIdAndModname::WithIdAndModnameMulti <tag:examples:with_id_and_modname:with_id_and_modname_multi> (JSI Schema Module)),
          "class.name": %q(JSI::SchemaClasses::XExamples_WithIdAndModname_WithIdAndModnameMulti__XExamples_WithIdAndModname_WithIdAndModnameMulti_AllOfModname__XExamples_WithIdAndModname_WithIdAndModnameMulti_allOf_0__XExamples_WithIdAndModname_WithIdAndModnameMulti_allOf_1),
          "class.inspect": %q((JSI Schema Class: Examples::WithIdAndModname::WithIdAndModnameMulti <tag:examples:with_id_and_modname:with_id_and_modname_multi> + Examples::WithIdAndModname::WithIdAndModnameMulti.allOf[0] + Examples::WithIdAndModname::WithIdAndModnameMulti.allOf[1] <tag:examples:with_id_and_modname:with_id_and_modname_multi:with_id> + Examples::WithIdAndModname::WithIdAndModnameMulti::AllOfModname)),
        },
        {
          "ptr": JSI::Ptr["definitions", "with_none", "definitions", "with_none"],
          "module.name_from_ancestor": nil,
          "module.inspect": %q((JSI Schema Module: #/definitions/with_none/definitions/with_none)),
          "class.name": %q(JSI::SchemaClasses::X0000_definitions_with_none_definitions_with_none),
          "class.inspect": %q((JSI Schema Class: #/definitions/with_none/definitions/with_none)),
        },
        {
          "ptr": JSI::Ptr["definitions", "with_none", "definitions", "with_none_multi"],
          "module.name_from_ancestor": nil,
          "module.inspect": %q((JSI Schema Module: #/definitions/with_none/definitions/with_none_multi)),
          "class.name": %q(JSI::SchemaClasses::X0000_definitions_with_none_definitions_with_none_multi__X0000_definitions_with_none_definitions_with_none_multi_allOf_0__Xtag_examples_anon_with_none_with_none_multi_with_id),
          "class.inspect": %q((JSI Schema Class: #/definitions/with_none/definitions/with_none_multi + #/definitions/with_none/definitions/with_none_multi/allOf/0 + tag:examples_anon:with_none:with_none_multi:with_id)),
        },
        {
          "ptr": JSI::Ptr["definitions", "with_none", "definitions", "with_id"],
          "module.name_from_ancestor": nil,
          "module.inspect": %q((JSI Schema Module: tag:examples_anon:with_none:with_id)),
          "class.name": %q(JSI::SchemaClasses::Xtag_examples_anon_with_none_with_id),
          "class.inspect": %q((JSI Schema Class: tag:examples_anon:with_none:with_id)),
        },
        {
          "ptr": JSI::Ptr["definitions", "with_none", "definitions", "with_id_multi"],
          "module.name_from_ancestor": nil,
          "module.inspect": %q((JSI Schema Module: tag:examples_anon:with_none:with_id_multi)),
          "class.name": %q(JSI::SchemaClasses::Xtag_examples_anon_with_none_with_id_multi__Xtag_examples_anon_with_none_with_id_multi_allOf_0__Xtag_examples_anon_with_none_with_id_multi_with_id__HashNode),
          "class.inspect": %q((JSI Schema Class: tag:examples_anon:with_none:with_id_multi + tag:examples_anon:with_none:with_id_multi#/allOf/0 + tag:examples_anon:with_none:with_id_multi:with_id)),
        },
        {
          "ptr": JSI::Ptr["definitions", "with_id", "definitions", "with_none"],
          "module.name_from_ancestor": nil,
          "module.inspect": %q((JSI Schema Module: tag:examples_anon:with_id#/definitions/with_none)),
          "class.name": %q(JSI::SchemaClasses::Xtag_examples_anon_with_id_definitions_with_none__ArrayNode),
          "class.inspect": %q((JSI Schema Class: tag:examples_anon:with_id#/definitions/with_none)),
        },
        {
          "ptr": JSI::Ptr["definitions", "with_id", "definitions", "with_none_multi"],
          "module.name_from_ancestor": nil,
          "module.inspect": %q((JSI Schema Module: tag:examples_anon:with_id#/definitions/with_none_multi)),
          "class.name": %q(JSI::SchemaClasses::Xtag_examples_anon_with_id_definitions_with_none_multi__Xtag_examples_anon_with_id_definitions_with_none_multi_allOf_0__Xtag_examples_anon_with_id_with_none_multi_with_id__StringNode),
          "class.inspect": %q((JSI Schema Class: tag:examples_anon:with_id#/definitions/with_none_multi + tag:examples_anon:with_id#/definitions/with_none_multi/allOf/0 + tag:examples_anon:with_id:with_none_multi:with_id)),
        },
        {
          "ptr": JSI::Ptr["definitions", "with_id", "definitions", "with_id"],
          "module.name_from_ancestor": nil,
          "module.inspect": %q((JSI Schema Module: tag:examples_anon:with_id:with_id)),
          "class.name": %q(JSI::SchemaClasses::Xtag_examples_anon_with_id_with_id),
          "class.inspect": %q((JSI Schema Class: tag:examples_anon:with_id:with_id)),
        },
        {
          "ptr": JSI::Ptr["definitions", "with_id", "definitions", "with_id_multi"],
          "module.name_from_ancestor": nil,
          "module.inspect": %q((JSI Schema Module: tag:examples_anon:with_id:with_id_multi)),
          "class.name": %q(JSI::SchemaClasses::Xtag_examples_anon_with_id_with_id_multi__Xtag_examples_anon_with_id_with_id_multi_allOf_0__Xtag_examples_anon_with_id_with_id_multi_with_id),
          "class.inspect": %q((JSI Schema Class: tag:examples_anon:with_id:with_id_multi + tag:examples_anon:with_id:with_id_multi#/allOf/0 + tag:examples_anon:with_id:with_id_multi:with_id)),
        },
      ]
    end
    let(:line_b) { __LINE__ }

    it 'has expected name / inspect' do
      assert_equal(examples, actual)
    end
  end
end
