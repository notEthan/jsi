# JSI: JSON Schema Instantiation

[![Build Status](https://travis-ci.org/notEthan/jsi.svg?branch=master)](https://travis-ci.org/notEthan/jsi)
[![Coverage Status](https://coveralls.io/repos/github/notEthan/jsi/badge.svg)](https://coveralls.io/github/notEthan/jsi)

JSI offers an Object-Oriented representation for JSON data using JSON Schemas. Given your JSON Schemas, JSI constructs Ruby modules and classes which are used to instantiate your JSON data. These modules let you use JSON with all the niceties of OOP such as property accessors and application-defined instance methods.

To learn more about JSON Schema see [https://json-schema.org/](https://json-schema.org/).

A JSI class aims to be a fairly unobtrusive wrapper around its instance - "instance" here meaning the JSON data, usually a Hash or Array, which instantiate the JSON Schema. JSI schema modules and classes add accessors for property names described by its schema, schema validation, and other nice things. Mostly though, you use a JSI as you would use its underlying data, calling the same methods (e.g. `#[]`, `#map`, `#repeated_permutation`) and passing it to anything that duck-types expecting `#to_ary` or `#to_hash`.

Note: The canonical location of this README is on [RubyDoc](http://rubydoc.info/gems/jsi/). When viewed on [Github](https://github.com/notEthan/jsi/), it may be inconsistent with the latest released gem, and Yardoc links will not work.

## Example

Words are boring, let's code. Here's a schema in yaml:

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

Using that schema, we instantiate a JSI::Schema to represent it:

```ruby
# this would usually load YAML or JSON; the schema object is inlined for copypastability.
contact_schema = JSI.new_schema({"$schema" => "http://json-schema.org/draft-07/schema", "description" => "A Contact", "type" => "object", "properties" => {"name" => {"type" => "string"}, "phone" => {"type" => "array", "items" => {"type" => "object", "properties" => {"location" => {"type" => "string"}, "number" => {"type" => "string"}}}}}})
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
# this would usually load YAML or JSON; the schema instance is inlined for copypastability.
bill = Contact.new_jsi({"name" => "bill", "phone" => [{"location" => "home", "number" => "555"}], "nickname" => "big b"})
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

Note that the keys are strings. JSI, being designed with JSON in mind, is geared toward string keys. Symbol keys will not match to schema properties, and so act the same as any other key not recognized from the schema.

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

We also get validations, as you'd expect given that's largely what json-schema exists to do:

```ruby
bill.jsi_valid?
# => true
```

... and validations on the nested schema instances (`#phone` here), showing in this example validation failure:

```ruby
bad = Contact.new_jsi({'phone' => [{'number' => [5, 5, 5]}]})
# => #{<JSI (Contact)>
#   "phone" => #[<JSI (Contact.properties["phone"])>
#     #{<JSI (Contact.properties["phone"].items)>
#       "number" => #[<JSI (Contact.properties["phone"].items.properties["number"])> 5, 5, 5]
#     }
#   ]
# }
bad.phone.jsi_validate
# => #<JSI::Validation::FullResult
#  @validation_errors=
#   #<Set: {#<JSI::Validation::Error
#      message: "instance type does not match `type` value",
#      keyword: "type",
#  ...
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
- a "JSI Schema" is a JSON Schema, instantiated as (usually) a JSI::Base described by a metaschema (see the sections on Metaschemas below). a JSI Schema is an instance of the module `JSI::Schema`.
- a "JSI schema module" is a module which represents one schema. Instances of that schema are extended with its JSI schema module. applications may reopen these modules to add functionality to JSI instances described by a given schema.
- a "JSI schema class" is a subclass of `JSI::Base` representing one or more JSON schemas. Instances of such a class are described by all of the represented schemas. A JSI schema class includes the JSI schema module of each represented schema.
- "instance" is a term that is significantly overloaded in this space, so documentation will attempt to be clear what kind of instance is meant:
  - a schema instance refers broadly to a data structure that is described by a JSON schema.
  - a JSI instance (or just "a JSI") is a ruby object instantiating a JSI schema class (subclass of `JSI::Base`). This wraps the content of the schema instance (see `JSI::Base#jsi_instance`), and ties it to the schemas which describe the instance (`JSI::Base#jsi_schemas`).
- "schema" refers to either a parsed JSON schema (generally a ruby Hash) or a JSI schema.

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

## Validation

JSI implements all required features, and many optional features, for validation according to supported JSON Schema specifications. To validate instances, see methods {JSI::Base#jsi_validate}, {JSI::Base#jsi_valid?}, {JSI::Schema#instance_validate}, {JSI::Schema#instance_valid?}.

The following optional features are not completely supported:

- The `format` keyword does not perform any validation.
- Regular expressions are interpreted by Ruby's Regexp class, whereas JSON Schema recommends interpreting these as ECMA 262 regular expressions. Certain expressions behave differently, particularly `^` and `$`.
- Keywords `contentMediaType` and `contentEncoding` do not perform validation.

## Metaschemas

A metaschema is a schema which describes schemas. Likewise, a schema is an instance of a metaschema.

In JSI, a schema is generally a JSI::Base instance whose schemas include a metaschema.

A self-descriptive metaschema - most commonly one of the JSON schema draft metaschemas - is an object whose schemas include itself. This is instantiated in JSI as a JSI::MetaschemaNode, a special subclass of JSI::Base.

## ActiveRecord serialization

A really excellent place to use JSI is when dealing with serialized columns in ActiveRecord.

Let's say you're sticking to JSON types in the database - you have to do so if you're using JSON columns, or JSON serialization, and if you have dealt with arbitrary yaml- or marshal-serialized objects in ruby, you have probably found that approach has its shortcomings when the implementation of your classes changes.

But if your database contains JSON, then your deserialized objects in ruby are likewise Hash / Array / basic types. You have to use subscripts instead of accessors, and you don't have any way to add methods to your data types.

JSI gives you the best of both with JSICoder. This coder dumps objects which are simple JSON types, and loads instances of a specified JSI schema. Here's an example, supposing a `users` table with a JSON column `contact_info`:

```ruby
class User < ActiveRecord::Base
  serialize :contact_info, JSI::JSICoder.new(Contact)
end
```

Now `user.contact_info` will be instantiated as a Contact JSI instance, from the JSON type in the database, with Contact's accessors, validations, and user-defined instance methods.

See the gem [`arms`](https://github.com/notEthan/arms) if you wish to serialize the dumped JSON-compatible objects further as text.

## Keying Hashes (JSON Objects)

Unlike Ruby, JSON only supports string keys. It is recommended to use strings as hash keys for all JSI instances, but JSI does not enforce this, nor does it do any key conversion. You may also use [ActiveSupport::HashWithIndifferentAccess](https://api.rubyonrails.org/classes/ActiveSupport/HashWithIndifferentAccess.html) as the instance of a JSI in order to gain the benefits that offers over a plain hash. Note that activesupport is not a dependency of jsi and would be required separately for this.

## Contributing

Issues and pull requests are welcome on GitHub at https://github.com/notEthan/jsi.

## License

[<img align="right" src="https://github.com/notEthan/jsi/raw/v0.3.0/resources/icons/AGPL-3.0.png">](https://www.gnu.org/licenses/agpl-3.0.html)

JSI is licensed under the terms of the [GNU Affero General Public License version 3](https://www.gnu.org/licenses/agpl-3.0.html).

Unlike the MIT or BSD licenses more commonly used with Ruby gems, this license requires that if you modify JSI and propagate your changes, e.g. by including it in a web application, your modified version must be publicly available. The common path of forking on Github should satisfy this requirement.
