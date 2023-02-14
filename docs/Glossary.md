# Glossary


## Background

The terminology JSI uses comes from a number of sources:

- [JSON Schema](https://json-schema.org/) and its [specifications](https://json-schema.org/specification-links.html)
  - The [JSON Schema Glossary](https://json-schema.org/learn/glossary.html)
- [JSON](https://www.json.org/) and its specification
- Tree data structure ([Wikipedia](https://en.wikipedia.org/wiki/Tree_(data_structure)))
- Object-oriented programming ([Wikipedia](https://en.wikipedia.org/wiki/Object-oriented_programming))
- The Ruby programming language
- [JSON Pointer](https://www.rfc-editor.org/rfc/rfc6901)

The terminology from these can be contradictory, e.g. 'object' in JSON meaning what is a Hash in Ruby, but 'object' in Ruby meaning any object as in object-oriented programming. This glossary aims to clarify any ambiguity and introduce any terms which may not be familiar to the reader.


## Terms


### JSI

[JSI]: #jsi
[a JSI]: #jsi

JSI is the name of this library. As a [countable](https://en.wikipedia.org/wiki/Count_noun), "a JSI" refers to the library's instantiation of an instance described by a set of [schema]s. This is a Ruby instance of {JSI::Base}, and also an instance of the [schema module] belonging to each schema that describes it (its {JSI::Base#jsi_schemas}).


### node

[node]: #node

A node is part of a [document] at a location identified by a [pointer].

In JSI a node generally means [a JSI] - a {JSI::Base} instance is often referred to just as "a JSI", but is referred to as a node in the context of its relationship to other nodes in its document.


### node content

[content]: #node_content

The content of a [node] is the parsed JSON instance.
It is generally a Ruby Hash, Array, String, Integer, Float or BigDecimal, true, false, or nil.

This content is referred to as the 'instance' in relation to [schema]s that describe it.

See {JSI::Base#jsi_node_content} (also aliased as {JSI::Base#jsi_instance}.


### document

[document]: #document

The document is the [content] of the [root] [node].

See {JSI::Base#jsi_document}.


### root

[root]: #root

A [node] representing the whole of a [document].

Its [pointer] is empty (has zero [token]s).

See {JSI::Base#jsi_root_node}.


### child

[child]: #child

A [node] immediately below another node, its [parent]. Identified by one [token] relative to the parent.

See {JSI::Base#[]} and {JSI::Base#jsi_child_node}.


### parent

[parent]: #parent

A [node] immediately above some number of other nodes, its [child]ren. Only a [hash/object] or [array] can be a parent.

See {JSI::Base#jsi_parent_node}.


### descendent

[descendent]: #descendent

A [node] anywhere below another node, its [ancestor]. Identified by a relative [pointer]. A node is considered to be a descendent of itself (at an empty relative pointer).

See {JSI::Base#jsi_descendent_node}, {JSI::Base#jsi_each_descendent_node}.


### ancestor

[ancestor]: #ancestor

A [node] above any number of other nodes, its [descendent]s. A node is considered to be an ancestor of itself, and the [root] node is an ancestor of every node in the [document].

See {JSI::Base#jsi_ancestor_nodes}.


### token

[token]: #token

An [array] [index] or [hash/object] [key/property name] that identifies a child node of its parent. Generally a String or non-negative Integer. [JSON Pointer](https://www.rfc-editor.org/rfc/rfc6901) calls this a "reference token".

A sequence of tokens comprises a [pointer].


### pointer

[pointer]: #pointer

A sequence of [token]s which identifies a [descendent] of a [node], instantiated as a {JSI::Ptr}.

[JSON Pointers](https://www.rfc-editor.org/rfc/rfc6901) are parsed to JSI pointers.

A pointer may be referred to as 'absolute' when identifying a descendent of the root node (see {JSI::Base#jsi_ptr}), or 'relative' identifying a descendent of any ancestor node (such as the pointer passed to {JSI::Base#jsi_descendent_node}).


### hash/object

[hash/object]: #hash_object

In JSON, an object; in Ruby, a Hash, or something [implicitly convertible](https://docs.ruby-lang.org/en/master/implicit_conversion_rdoc.html) with `#to_hash`.

In JSI, a [node] whose content is a Hash/`#to_hash`, and which is a {JSI::Base::HashNode}). These nodes are largely used as one would use a Hash, aiming to replicate Hash's API, as well being implicitly convertible with `#to_hash`.

A hash/object has [child] nodes on each [key/property name].


### array

[array]: #array

In JSON, an array; in Ruby, an Array, or something [implicitly convertible](https://docs.ruby-lang.org/en/master/implicit_conversion_rdoc.html) with `#to_ary`.

In JSI, a [node] whose content is an Array/`#to_ary`, and which is a {JSI::Base::ArrayNode}). These nodes are largely used as one would use an Array, aiming to replicate Array's API, as well being implicitly convertible with `#to_ary`.

An array has [child] nodes on each [index].


### key/property name

[key/property name]: #key_property_name

A [token] identifying a [child] of a [hash/object] [node]. In Ruby, a Hash key; in JSON Schema, an object property name. Property names are always strings in JSON. Note that symbols are not compatible and generally should not be used.

Property names can be described by schemas (using the `propertyNames` keyword), and can be JSI instances of those schemas. See {JSI::Base::HashNode#jsi_each_propertyName}.


### index

[index]: #index

A [token] identifying a [child] of an [array] [node]. A non-negative integer. This may be represented in string form in a [pointer].


### instance

[instance]: #instance

A heavily-overloaded term. Context should make it clear in what sense it is being used. 'Instance' can refer to an *object* or a *relationship*, in Ruby or JSON Schema or JSI instantiation:

  - JSON Schema: the *instance* (JSON data) is an *instance* (relationship) of JSON Schemas that describe it
  - Ruby: the *instance* (an Object) is an *instance* (relationship) of a Class and included Modules
  - JSI: the *instance* ([a JSI]) is an *instance* (relationship) of [JSI Schemas][schema]

These all operate in parallel in JSI: a JSI instance represents a JSON instance, it is described by JSI Schemas which represent JSON Schemas, and it is a Ruby instance of the [JSI Schema Modules][schema module] of the schemas that describe it.


### schema

[schema]: #schema

A JSI Schema is [a JSI] that represents a JSON Schema. It is a Ruby instance of {JSI::Base} and the module {JSI::Schema}.

A schema describes a set of [instance]s. Any JSI instance that is described by a given schema is a Ruby instance of that schema's [schema module].

A schema is described by a [meta-schema] and is a Ruby instance of that meta-schema's [schema module].


### schema module

[schema module]: #schema_module

A JSI Schema Module is a Ruby module associated with a particular [schema]. Any JSI instance that is described by that schema is a Ruby instance of the schema's schema module. This is a {JSI::SchemaModule}.

See {JSI::Schema#jsi_schema_module}.

A JSI Schema Module is not to be confused with the module {JSI::Schema} - a schema *is* a Ruby instance of the module JSI::Schema, and it *has* a JSI Schema Module. The module JSI::Schema is included on the JSI Schema module of a [meta-schema].


### meta-schema

[meta-schema]: #meta-schema

A meta-schema is a [schema] that describes schemas, i.e. [instance]s of the meta-schema are schemas.

As with any other JSI instance, a JSI schema is an instance of the [schema module] of the meta-schema that describes it. The meta-schema's schema module defines the functionality for its instances to behave as schemas. It includes the module {JSI::Schema}.

A meta-schema is described by a meta-schema, which may be itself or another meta-schema. Examples of self-describing meta-schemas are the JSON Schema meta-schemas. An example of the latter is the [schema describing the OpenAPI v3.0 Schema object](https://github.com/OAI/OpenAPI-Specification/blob/3.0.3/schemas/v3.0/schema.yaml#L203), which describes schemas in OpenAPI documents, but is itself described by the JSON Schema draft-04 meta-schema.

A self-describing meta-schema is a Ruby instance of its own schema module.

A meta-schema has a [dialect] that defines the functionality of the schemas it describes.

In JSI, a meta-schema is a {JSI::Base} that is a {JSI::Schema::MetaSchema}. Its schema module is a {JSI::SchemaModule::MetaSchemaModule}, and includes {JSI::Schema}. See also {JSI::Schema#describes_schema?} and {JSI::Schema#describes_schema!}.


### resource

[resource]: #resource

A resource, or schema resource, is either:

- A [schema] that is identified by an absolute URI (typically declared with an id keyword)
- The root of a document containing schemas, whether or not the root is itself a schema. (Technically the root of any document can be considered a resource, but it is only useful when the document contains schemas.)

For a given node, its *resource root* is the nearest ancestor that is a resource - this is distinct from the [root] node of the whole document.

Relative URIs and [pointer]s used by a schema (e.g. in `$ref` or `$id`) are resolved relative to its resource root and that resource's id.

See {JSI::Schema#schema_resource_root}.
