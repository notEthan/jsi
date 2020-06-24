# v0.4.0

- a JSI::Base has multiple jsi_schemas https://github.com/notEthan/jsi/pull/88
  - JSI.class_for_schemas replaces JSI.class_for_schema
- fix uri/fragment nomenclature https://github.com/notEthan/jsi/pull/89

# v0.3.0

- a schema is a JSI instance of a metaschema
- module JSI::Schema
- module JSI::Metaschema
- class JSI::MetaschemaNode
- JSI::JSON::Node breaking changes
- module SimpleWrap https://github.com/notEthan/jsi/pull/87

# v0.2.1

- bugfix JSI::Schema#described_object_property_names looks only at allOf, not oneOf/anyOf
- rm unused Schema#default_value, #default_value?
- misc

# v0.2.0

- JSI::PathedNode unifies interfaces of JSI::Base, JSI::JSON::Node
- JSI::Base does not (generally) wrap a JSI::JSON::Node
- some method renames to try to better indicate what a method applies to, and unreserve common names
  - JSI::Base
    - #instance -> #jsi_instance
    - #parents -> #parent_jsis, #parent -> #parent_jsi
  - JSI::Schema
    - #fully_validate -> #fully_validate_instance
    - #validate -> #validate_instance
    - #validate! -> #validate_instance!
- improvements to methods which use a modified copy - #dup, #update/#merge
- #deref on PathedNode classes uses a block form
- JSI::PathedArrayNode, PathedHashNode
- JSI::JSON::Pointer refactoring and improvement
- Schema#new_jsi
- JSI::SimpleWrap
- more

# v0.1.0

- JSI::JSON::Pointer replaces monkey-patched-in ::JSON::Schema::Pointer
- JSI::JSICoder replaces JSI::SchemaInstanceJSONCoder / ObjectJSONCoder
- remove JSI::StructJSONCoder
- misc improvements to code, doc, tests

# v0.0.4

- minor bugfixes / improvements

# v0.0.3

- JSI::Base returns an instance of the default value for the schema if applicable
- JSI::Base instance method #class_for_schema may be overridden by subclasses
- bugfixes and internal refactoring

# v0.0.2

- JSI::JSON::Node and other utilities duck-type better with #to_hash and #to_ary
- much improved documentation
- much improved test coverage
- code improvements too numerous to list

# v0.0.1

- extracted JSI from Scorpio
