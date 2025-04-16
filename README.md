# JSI: JSON Schema Instantiation

![Test CI Status](https://github.com/notEthan/jsi/actions/workflows/test.yml/badge.svg?branch=main)
[![Coverage Status](https://coveralls.io/repos/github/notEthan/jsi/badge.svg)](https://coveralls.io/github/notEthan/jsi)

JSI offers an Object-Oriented representation for JSON data using JSON Schemas. Given your JSON Schemas, JSI constructs Ruby modules and classes which are used to instantiate your JSON data. These modules let you use JSON with all the niceties of OOP such as property accessors and application-defined instance methods.

To learn more about JSON Schema see <https://json-schema.org/>.

JSI marries object-oriented programming with JSON Schemas by associating a module with each schema, and extending every instance described by a schema with that module. When an application adds methods to a schema module, those methods can be used on its instances.

A JSI instance aims to offer a fairly unobtrusive wrapper around its JSON data, which is usually a Hash (JSON Object) or Array described by one or more JSON Schemas. JSI instances have accessors for property names described by schemas, schema validation, and other nice things. Mostly though, you use a JSI as you would use its underlying data, calling the same methods (e.g. `#[]`, `#map`, `#repeated_permutation`) and passing it to anything that duck-types expecting `#to_ary` or `#to_hash`.

Note: The canonical location of this README is on [RubyDoc](http://rubydoc.info/gems/jsi/). When viewed on [Github](https://github.com/notEthan/jsi/), it may be inconsistent with the latest released gem, and Yardoc links will not work.

## Example

Words are boring, let's code. You can follow along from the code blocks - install the gem (`gem install jsi`), load an irb (`irb -r jsi`), and copy/paste/hack.

Here's a schema in yaml:

```yaml
$schema: "http://json-schema.org/draft-07/schema"
description: "A Contact"
type: "object"
properties:
  name: {type: "string"}
  phone:
    type: "array"
    items:
      description: "A phone number"
      type: "object"
      properties:
        location: {type: "string"}
        number: {type: "string"}
```

We pass that to {JSI.new_schema} which will instantiate a JSI Schema which represents it:

```ruby
# this would usually load YAML or JSON; the schema object is inlined for copypastability.
contact_schema = JSI.new_schema({"$schema" => "http://json-schema.org/draft-07/schema", "description" => "A Contact", "type" => "object", "properties" => {"name" => {"type" => "string"}, "phone" => {"type" => "array", "items" => {"type" => "object", "properties" => {"location" => {"type" => "string"}, "number" => {"type" => "string"}}}}}})
```

We name the module that JSI will use when instantiating a contact. Named modules are better to work with, and JSI will indicate the names of schema modules in its `#inspect` output.

```ruby
Contact = contact_schema.jsi_schema_module
```

Note: it is more concise to instantiate the schema module with the shortcut {JSI.new_schema_module}, i.e. `Contact = JSI.new_schema_module(...)`. This example includes the intermediate step to help show all that is happening.

To instantiate the schema, we need some JSON data (expressed here as YAML)

```yaml
name: bill
phone:
- location: home
  number: "555"
nickname: big b
```

So, if we construct an instance like:

```ruby
bill = Contact.new_jsi(
  # this would typically load JSON or YAML; the schema instance is inlined for copypastability.
  {"name" => "bill", "phone" => [{"location" => "home", "number" => "555"}], "nickname" => "big b"},
  # note: bill is mutable to demonstrate setters below; the default is immutable.
  mutable: true
)
# => #{<JSI (Contact)>
#   "name" => "bill",
#   "phone" => #[<JSI (Contact.properties["phone"])>
#     #{<JSI (Contact.properties["phone"].items)>
#       "location" => "home",
#       "number" => "555"
#     }
#   ],
#   "nickname" => "big b"
# }
```

Note that the hash keys are strings. JSI, being designed with JSON in mind, is geared toward string keys.

We get accessors for the Contact:

```ruby
bill.name
# => "bill"
```

but also nested accessors - `#phone` is an instance of its array-type schema, and each phone item is an instance of another object-type schema with `#location` and `#number` accessors:

```ruby
bill.phone.map(&:location)
# => ["home"]
```

We also get validations, as you'd expect given that's largely what JSON Schema exists to do:

```ruby
bill.jsi_valid?
# => true
```

... and validations on the nested schema instances (`#phone` here), showing in this example validation failure on /phone/0/number:

```ruby
bad = Contact.new_jsi({'phone' => [{'number' => [5, 5, 5]}]})
# => #{<JSI (Contact)>
#   "phone" => #[<JSI (Contact.properties["phone"])>
#     #{<JSI (Contact.properties["phone"].items)>
#       "number" => #[<JSI (Contact.properties["phone"].items.properties["number"])> 5, 5, 5]
#     }
#   ]
# }
bad.phone[0].jsi_validate
# =>
# #<JSI::Validation::Result::Full (INVALID)
#   validation errors: JSI::Set[
#     #<JSI::Validation::Error
#       message: "instance object properties are not all valid against corresponding `properties` schemas",
#       instance: {"number" => [5, 5, 5]},
#       instance_ptr: JSI::Ptr["phone", 0],
#       keyword: "properties",
#       schema uri: JSI::URI["#/properties/phone/items"],
#       nested_errors: JSI::Set[
#         #<JSI::Validation::Error
#           message: "instance type does not match `type` value",
#           instance: [5, 5, 5],
#           instance_ptr: JSI::Ptr["phone", 0, "number"],
#           keyword: "type",
#           schema uri: JSI::URI["#/properties/phone/items/properties/number"],
#           nested_errors: JSI::Set[]
#         >
#       ]
#     >
#   ]
# >
```

Since the underlying instance is a ruby hash (json object), we can use it like a hash with `#[]` or, say, `#transform_values`:

```ruby
# note that #size here is actually referring to multiple different methods;
# for name and nickname it is String#size but for phone it is Array#size.
bill.transform_values(&:size)
# => {"name" => 4, "phone" => 1, "nickname" => 5}

bill['nickname']
# => "big b"
```

There's plenty more JSI has to offer, but this should give you a pretty good idea of basic usage.

## Terminology and Concepts

- `JSI::Base` is the base class for each JSI schema class representing instances of JSON Schemas.
- a "JSI Schema" is a JSON Schema, instantiated as (usually) a JSI::Base described by a meta-schema (see the section on meta-schemas below). A JSI Schema is an instance of the module `JSI::Schema`.
- a "JSI Schema Module" is a module which represents one schema, dynamically created by that Schema. Instances of that schema are extended with its JSI schema module. applications may reopen these modules to add functionality to JSI instances described by a given schema.
- a "JSI schema class" is a subclass of `JSI::Base` representing any number of JSON schemas. Instances of such a class are described by all of the represented schemas. A JSI schema class includes the JSI schema module of each represented schema.
- "instance" is a term that is significantly overloaded in this space, so documentation will attempt to be clear what kind of instance is meant:
  - a schema instance refers broadly to a data structure that is described by a JSON schema.
  - a JSI instance (or just "a JSI") is a ruby object instantiating a JSI schema class (subclass of `JSI::Base`). This wraps the content of the schema instance (see `JSI::Base#jsi_instance`), and ties it to the schemas which describe the instance (`JSI::Base#jsi_schemas`).
- "schema" refers to either a parsed JSON schema (generally a ruby Hash) or a JSI schema.

## Supported specification versions

JSI supports these JSON Schema specification versions:

| Version | `$schema` URI                             | JSI Schema Module |
| ---     | ---                                       | ---               |
| Draft 4 | `http://json-schema.org/draft-04/schema#` | {JSI::JSONSchemaDraft04} |
| Draft 6 | `http://json-schema.org/draft-06/schema#` | {JSI::JSONSchemaDraft06} |
| Draft 7 | `http://json-schema.org/draft-07/schema#` | {JSI::JSONSchemaDraft07} |
| Draft 2020-12 | `https://json-schema.org/draft/2020-12/schema` | {JSI::JSONSchemaDraft202012} |

Caveats:

- Regular expressions are interpreted by Ruby's Regexp class, whereas JSON Schema recommends interpreting these as ECMA 262 regular expressions. Certain expressions behave differently, particularly `^` and `$`.
- The `format` keyword does not perform validation. This may be implemented in the future.
- Draft 2020-12: `$schema` has no effect except at the document root ([#341](https://github.com/notEthan/jsi/issues/341))
- Draft 7: Keywords `contentMediaType` and `contentEncoding` do not perform validation.
- Draft 4: `$ref` is only used as a reference from schemas - it will not be followed when used on objects that are not schemas. This is consistent with specifications since Draft 4, but in Draft 4 the [JSON Reference](https://datatracker.ietf.org/doc/html/draft-pbryan-zyp-json-ref-03) specification would allow `$ref` to be used anywhere. JSI does not do this.

## JSI and Object Oriented Programming

Instantiating your schema is a starting point. But, since the major point of object-oriented programming is applying methods to your objects, of course you want to be able to define your own methods. To do this we reopen the JSI module we defined. Referring back to the Example section above, we reopen the `Contact` module:

```ruby
module Contact
  def phone_numbers
    phone.map(&:number)
  end
  def name
    super + ' esq.'
  end
  def name=(name)
    super(name.chomp(' esq.'))
  end
end

bill.phone_numbers
# => ["555"]

bill.name
# => "bill esq."
bill.name = 'rob esq.'
# => "rob esq."
bill['name']
# => "rob"
```

`#phone_numbers` is a new method returning each number in the `phone` array - pretty straightforward.

For `#name` and `#name=`, we're overriding existing accessor methods. note the use of `super` - this invokes the accessor methods defined by JSI which these override. You could alternatively use `self['name']` and `self['name']=` in these methods, with the same effect as `super`.

Working with subschemas to add methods is just about as easy as with root schemas.

You can subscript or use property accessors on a JSI schema module to refer to the schema modules of its subschemas, e.g.:

```ruby
Contact.properties['phone'].items
# => Contact.properties["phone"].items (JSI Schema Module)
```

Opening a subschema module with [`module_exec`](https://ruby-doc.org/core/Module.html#method-i-module_exec), you can add methods to instances of the subschema.

```ruby
Contact.properties['phone'].items.module_exec do
  def number_with_dashes
    number.split(//).join('-')
  end
end
bill.phone.first.number_with_dashes
# => "5-5-5"
```

A recommended convention for naming subschemas is to define them in the namespace of the module of their parent schema. The module can then be opened to add methods to the subschema's module.

```ruby
module Contact
  Phone = properties['phone'].items
  module Phone
    def number_with_dashes
      number.split(//).join('-')
    end
  end
end
```

However, that is only a convention, and a flat namespace works fine too.

```ruby
ContactPhone = Contact.properties['phone'].items
module ContactPhone
  def number_with_dashes
    number.split(//).join('-')
  end
end
```

### A note on Classes

The classes used to instantiate JSIs are dynamically generated subclasses of JSI::Base which include the JSI Schema Module of each schema describing the given instance. These are mostly intended to be ignored: applications aren't expected to instantiate these directly (rather, `#new_jsi` on a Schema or Schema Module is intended), and they are not intended for subclassing or method definition (applications should instead define methods on a schema's {JSI::Schema#jsi_schema_module}).

## Mutability

JSI instances are immutable by default. Mutable JSIs may be instantiated using the `mutable` param of `new_jsi`. Immutable JSIs are much more performant, because mutation may change what schemas apply to nodes in a document, and checking for that is costly. It is not recommended to instantiate large documents as mutable; their JSI instances become unusably slow.

If you are parsing with JSON.parse or YAML.load, it is recommended to pass the `freeze: true` option to these, which lets JSI skip making a frozen copy.

## Registration

In order for references across documents (generally from a `$ref` schema keyword) to resolve, JSI provides a registry (a {JSI::Registry}) which associates URIs with schemas (or resources containing schemas). The default registry is accessible on {JSI.registry}.

Schemas instantiated with `.new_schema`, and their subschemas, are by default registered with `JSI.registry` if they are identified by an absolute URI. This can be controlled by params `register` and `registry`.

Schemas can automatically be lazily loaded by registering a block which instantiates them with {JSI::Registry#autoload_uri} (see its documentation).

## Validation

JSI implements all required features, and many optional features, for validation according to supported JSON Schema specifications. To validate instances, see methods {JSI::Base#jsi_validate}, {JSI::Base#jsi_valid?}, {JSI::Schema#instance_validate}, {JSI::Schema#instance_valid?}.

## Meta-Schemas

A meta-schema is a schema that describes schemas. Likewise, a schema is an instance of a meta-schema.

In JSI, a schema is generally a JSI::Base instance whose schemas include a meta-schema.

A self-descriptive meta-schema - most commonly one of the JSON schema draft meta-schemas - is an object whose schemas include itself. This is instantiated in JSI as a JSI::MetaSchemaNode, a special subclass of JSI::Base.

## ActiveRecord serialization

A really excellent place to use JSI is when dealing with serialized columns in ActiveRecord.

Let's say you're sticking to JSON types in the database - you have to do so if you're using JSON columns, or JSON serialization, and if you have dealt with arbitrary yaml- or marshal-serialized objects in ruby, you have probably found that approach has its shortcomings when the implementation of your classes changes.

But if your database contains JSON, then your deserialized objects in ruby are likewise Hash / Array / simple types. You have to use subscripts instead of accessors, and you don't have any way to add methods to your data types.

JSI gives you the best of both with {JSI::JSICoder}. This coder dumps objects which are simple JSON types, and loads instances of a specified JSON Schema. Here's an example, supposing a `users` table with a JSON column `contact_info` to be instantiated using the `Contact` schema module defined in the Example section above:

```ruby
class User < ActiveRecord::Base
  serialize :contact_info, JSI::JSICoder.new(Contact)
end
```

Now `user.contact_info` will be instantiated as a `Contact` JSI instance, from the JSON type in the database, with Contact's accessors, validations, and application-defined instance methods.

See the gem [`arms`](https://github.com/notEthan/arms) if you wish to serialize the dumped JSON-compatible objects further as text.

## Keying Hashes (JSON Objects)

Unlike Ruby, JSON only supports string keys. It is recommended to use strings as hash keys for all JSI instances, but JSI does not enforce this, nor does it do any key conversion. You may also use [ActiveSupport::HashWithIndifferentAccess](https://api.rubyonrails.org/classes/ActiveSupport/HashWithIndifferentAccess.html) as the instance of a JSI in order to gain the benefits that offers over a plain hash. Note that activesupport is not a dependency of jsi and would be required separately for this.

## Contributing

Issues and pull requests are welcome on GitHub at https://github.com/notEthan/jsi.

## License

[<img align="right" src="https://www.gnu.org/graphics/agplv3-155x51.png">](https://www.gnu.org/licenses/agpl-3.0.html)

JSI is licensed under the terms of the [GNU Affero General Public License version 3](https://www.gnu.org/licenses/agpl-3.0.html).

Unlike the MIT or BSD licenses more commonly used with Ruby gems, this license requires that if you modify JSI and propagate your changes, e.g. by including it in a web application, your modified version must be publicly available. The common path of forking on Github should satisfy this requirement.
