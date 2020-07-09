# JSI: JSON Schema Instantiation

[![Build Status](https://travis-ci.org/notEthan/jsi.svg?branch=master)](https://travis-ci.org/notEthan/jsi)
[![Coverage Status](https://coveralls.io/repos/github/notEthan/jsi/badge.svg)](https://coveralls.io/github/notEthan/jsi)

JSI offers an Object-Oriented representation for JSON data using JSON Schemas. Given your JSON Schemas, JSI constructs Ruby modules and classes which are used to instantiate your JSON data. These modules let you use JSON with all the niceties of OOP such as property accessors and application-defined instance methods.

To learn more about JSON Schema see [https://json-schema.org/]().

A JSI class aims to be a fairly unobtrusive wrapper around its instance - "instance" here meaning the JSON data, usually a Hash or Array, which instantiate the JSON Schema. JSI schema modules and classes add accessors for property names described by its schema, schema validation, and other nice things. Mostly though, you use a JSI as you would use its underlying data, calling the same methods (e.g. `#[]`, `#map`, `#repeated_permutation`) and passing it to anything that duck-types expecting `#to_ary` or `#to_hash`.

## Example

Words are boring, let's code. Here's a schema in yaml:

```yaml
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

Using that schema, we instantiate a JSI::Schema to represent it:

```ruby
# this would usually use a YAML.load/JSON.parse/whatever; it's inlined for copypastability.
contact_schema = JSI::Schema.new({"description" => "A Contact", "type" => "object", "properties" => {"name" => {"type" => "string"}, "phone" => {"type" => "array", "items" => {"type" => "object", "properties" => {"location" => {"type" => "string"}, "number" => {"type" => "string"}}}}}})
```

We name the module that JSI will use when instantiating a contact. Named modules are better to work with, and JSI will indicate the names of schema modules in its `#inspect` output.

```ruby
Contact = contact_schema.jsi_schema_module
```

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
# this would usually use a YAML.load/JSON.parse/whatever; it's inlined for copypastability.
bill = Contact.new_jsi({"name" => "bill", "phone" => [{"location" => "home", "number" => "555"}], "nickname" => "big b"})
# => #{<JSI (Contact)>
#   "name" => "bill",
#   "phone" => #[<JSI>
#     #{<JSI>
#       "location" => "home",
#       "number" => "555"
#     }
#   ],
#   "nickname" => "big b"
# }
```

Note that the keys are strings. JSI, being designed with JSON in mind, is geared toward string keys. Symbol keys will not match to schema properties, and so act the same as any other key not recognized from the schema.

We get accessors for the Contact:

```ruby
bill.name
# => "bill"
```

but also nested accessors - #phone is an instance of its array-type schema, and each phone item is an instance of another object-type schema with location and number accessors:

```ruby
bill.phone.map(&:location)
# => ["home"]
```

We also get validations, as you'd expect given that's largely what json-schema exists to do:

```ruby
bill.validate
# => true
```

... and validations on the nested schema instances (#phone here), showing in this example validation failure:

```ruby
bad = Contact.new_jsi({'phone' => [{'number' => [5, 5, 5]}]})
# => #{<JSI (Contact)>
#   "phone" => #[<JSI>
#     #{<JSI>
#       "number" => #[<JSI> 5, 5, 5]
#     }
#   ]
# }
bad.phone.fully_validate
# => ["The property '#/0/number' of type array did not match the following type: string in schema 594126e3"]
```

These validations are done by the [`json-schema` gem](https://github.com/ruby-json-schema/json-schema) - JSI does not do validations on its own.

Since the underlying instance is a ruby hash (json object), we can use it like a hash with `#[]` or, say, `#transform_values`:

```ruby
# note that #size here is actually referring to multiple different methods; for name and nickname
# it is String#size but for phone it is Array#size.
bill.transform_values(&:size)
# => {"name" => 4, "phone" => 1, "nickname" => 5}
bill['nickname']
# => "big b"
```

There's plenty more JSI has to offer, but this should give you a pretty good idea of basic usage.

## Terminology and Concepts

- `JSI::Base` is the base class for each JSI class representing a JSON Schema.
- a "JSI class" is a subclass of `JSI::Base` representing a JSON schema.
- a "JSI schema module" is a module representing a schema, included on a JSI class.
- "instance" is a term that is significantly overloaded in this space, so documentation will attempt to be clear what kind of instance is meant:
  - a schema instance refers broadly to a data structure that is described by a JSON schema.
  - a JSI instance (or just "a JSI") is a ruby object instantiating a JSI class. it has a method `#jsi_instance` which contains the underlying data.
- a schema refers to a JSON schema. `JSI::Schema` is a module which extends schemas. A schema is usually a `JSI::Base` instance, and that schema JSI's schema is a metaschema (see the sections on Metaschemas below).

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

bill.name
# => "bill esq."
bill.name = 'rob esq.'
# => "rob esq."
bill['name']
# => "rob"
bill.phone_numbers
# => ["555"]
```

Note the use of `super` - you can call to accessors defined by JSI and make your accessors act as wrappers. You can alternatively use `[]` and `[]=` with the same effect.

Working with subschemas is just about as easy as with root schemas.

You can subscript or use property accessors on a JSI schema module to refer to the schema modules of its subschemas, e.g.:

```ruby
Contact.properties['phone'].items
# => (JSI Schema Module: #/properties/phone/items)
```

Opening a subschema module with module_eval, you can add methods to instances of the subschema.

```ruby
Contact.properties['phone'].items.module_eval do
  def number_with_dashes
    number.split(//).join('-')
  end
end
bill.phone.first.number_with_dashes
# => "5-5-5"
```

A recommended convention for naming subschemas is to define them in the namespace of the module of their
parent schema. The module can then be opened to add methods to the subschema's module.

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

## Metaschemas

A metaschema is a schema which describes schemas. Likewise, a schema is an instance of a metaschema.

In JSI, a schema is generally a JSI::Base instance whose schema is a metaschema.

A self-descriptive metaschema - most commonly one of the JSON schema draft metaschemas - is an object whose schema is itself. This is instantiated in JSI as a JSI::MetaschemaNode (not a JSI::Base).

## ActiveRecord serialization

A really excellent place to use JSI is when dealing with serialized columns in ActiveRecord.

Let's say you're sticking to JSON types in the database - you have to do so if you're using JSON columns, or JSON serialization, and if you have dealt with arbitrary yaml- or marshal-serialized objects in ruby, you have probably found that approach has its shortcomings when the implementation of your classes changes.

But if your database contains JSON, then your deserialized objects in ruby are likewise Hash / Array / basic types. You have to use subscripts instead of accessors, and you don't have any way to add methods to your data types.

JSI gives you the best of both with JSICoder. This coder dumps objects which are simple JSON types, and loads instances of a specified JSI schema. Here's an example:

```ruby
class User < ActiveRecord::Base
  serialize :contact_info, JSI::JSICoder.new(Contact)
end
```

Now `user.contacts` will return an array of Contact instances, from the JSON type in the database, with Contact's accessors, validations, and user-defined instance methods.

See the gem [`arms`](https://github.com/notEthan/arms) if you wish to serialize the dumped JSON-compatible objects further as text.

## Keying Hashes (JSON Objects)

Unlike Ruby, JSON only supports string keys. It is recommended to use strings as hash keys for all JSI instances, but JSI does not enforce this, nor does it do any key conversion. It should be possible to use ActiveSupport::HashWithIndifferentAccess as the instance of a JSI in order to gain the benefits that offers over a plain hash. This is not tested behavior, but JSI should behave correctly with any instance that responds to #to_hash.

## Contributing

Issues and pull requests are welcome on GitHub at https://github.com/notEthan/jsi.

## License

[<img align="right" src="https://github.com/notEthan/jsi/raw/master/resources/icons/AGPL-3.0.png">](https://www.gnu.org/licenses/agpl-3.0.html)

JSI is licensed under the terms of the [GNU Affero General Public License version 3](https://www.gnu.org/licenses/agpl-3.0.html).

Unlike the MIT or BSD licenses more commonly used with Ruby gems, this license requires that if you modify JSI and propagate your changes, e.g. by including it in a web application, your modified version must be publicly available. The common path of forking on Github should satisfy this requirement.
