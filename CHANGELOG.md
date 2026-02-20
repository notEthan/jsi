# v0.9.0

- JSON Schema draft 2020-12 (JSI::JSONSchemaDraft202012)
- new architecture for Schema with Dialect, Vocabulary, Element
- Base#jsi_conf / Base::Conf
- JSI.translator
- Base#jsi_valid!, Schema#instance_valid!
- much more

# v0.8.1

- JSIs are immutable by default

# v0.8.0

- Immutable JSIs with new_jsi param `mutable`
  - JSIs are still mutable by default, but in the next release they will default to immutable
- Base#jsi_indicated_schemas
- Base::StringNode

# v0.7.0

- PathedHashNode -> Base::HashNode, PathedArrayNode -> Base::ArrayNode, PathedNode merged with Base
- change application of conditional schemas to instances which do not validate, always apply them
- add Schema#describes_schema!, deprecate Schema#jsi_schema_instance_modules
- MetaschemaNode keeps its jsi_root_node (reducing an enormous number of unnecessary instantiations of MetaschemaNode)

# v0.6.0

- initial validation; remove gem `json-schema` dependency
- JSI.new_schema / new_schema_module
- JSI::SchemaSet
- JSI::SchemaRegistry
- JSI::Schema::Ref
- JSI::JSON::Pointer → JSI::Ptr
- remove JSI::JSON::Node

# v0.4.0

- a JSI::Base has multiple jsi_schemas https://github.com/notEthan/jsi/pull/88

# v0.3.0

- a schema is a JSI instance of a metaschema
- module JSI::Schema
- module JSI::Metaschema
- class JSI::MetaschemaNode

# v0.2.0

- JSI::PathedNode unifies interfaces of JSI::Base, JSI::JSON::Node
- JSI::Base does not (generally) wrap a JSI::JSON::Node
- JSI::PathedArrayNode, PathedHashNode
- Schema#new_jsi

# v0.0.1

- extracted JSI from Scorpio
