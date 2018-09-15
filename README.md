# JSI: JSON-Schema Instantiation

[![Build Status](https://travis-ci.org/notEthan/jsi.svg?branch=master)](https://travis-ci.org/notEthan/jsi)
[![Coverage Status](https://coveralls.io/repos/github/notEthan/jsi/badge.svg)](https://coveralls.io/github/notEthan/jsi)

JSI represents JSON-schemas as ruby classes, and schema instances as instances of those classes.

A JSI class aims to be a fairly unobtrusive wrapper around its instance. It adds accessors for known property names, validation methods, and a few other nice things. Mostly though, you use a JSI as you would use its underlying data, calling the same methods (e.g. `#[]`, `#map`, `#repeated_permutation`) and passing it to anything that duck-types expecting #to_ary or #to_hash.

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
      type: "object"
      properties:
        location: {type: "string"}
        number: {type: "string"}
```

And here's the class for that schema from JSI:

```ruby
Contact = JSI.class_for_schema(YAML.load_file('contact.schema.yml'))
# you can copy/paste this line instead, to follow along in irb:
Contact = JSI.class_for_schema({"description" => "A Contact", "type" => "object", "properties" => {"name" => {"type" => "string"}, "phone" => {"type" => "array", "items" => {"type" => "object", "properties" => {"location" => {"type" => "string"}, "number" => {"type" => "string"}}}}}})
```

This definition gives you not just the Contact class, but classes for the whole nested structure. So, if we construct an instance like:

```ruby
bill = Contact.new(name: 'bill', phone: [{location: 'home', number: '555'}], nickname: 'big b')
# => #{<Contact fragment="#">
# #{<Contact fragment="#">
#   "phone" => #[<JSI::SchemaClasses["1f97#/properties/phone"] fragment="#/phone">
#     #{<JSI::SchemaClasses["1f97#/properties/phone/items"] fragment="#/phone/0"> "location" => "home", "number" => "555"}
#   ],
#   "nickname" => "big b"
# }
```

The nested classes can be seen as `JSI::SchemaClasses[schema_id]` where schema_id is a generated value.

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
bad = Contact.new(phone: [{number: [5, 5, 5]}])
# => #{<Contact fragment="#">
#   "phone" => #[<JSI::SchemaClasses["1f97#/properties/phone"] fragment="#/phone">
#     #{<JSI::SchemaClasses["1f97#/properties/phone/items"] fragment="#/phone/0">
#       "number" => #[<JSI::SchemaClasses["1f97#/properties/phone/items/properties/number"] fragment="#/phone/0/number"> 5, 5, 5]
#     }
#   ]
# }
bad.phone.fully_validate
# => ["The property '#/0/number' of type array did not match the following type: string in schema 1f97"]
```

Since the underlying instance is a ruby hash (json object), we can use it like a hash with #[] or, say, #transform_values:

```ruby
bill.transform_values(&:size)
# => {"name" => 4, "phone" => 1, "nickname" => 5}
bill['nickname']
# => "big b"
```

There's plenty more JSI has to offer, but this should give you a pretty good idea of basic usage.

## Terminology and Concepts

- JSI::Base is the base class from which other classes representing JSON-Schemas inherit.
- a JSI class refers to a class representing a schema, a subclass of JSI::Base.
- "instance" is a term that is significantly overloaded in this space, so documentation will attempt to be clear what kind of instance is meant:
  - a schema instance refers broadly to a data structure that is described by a json-schema.
  - a JSI instance (or just "a JSI") is a ruby object instantiating a JSI class. it has a method #instance which contains the underlying data.
- a schema refers to a json-schema. a JSI::Schema represents such a json-schema. a JSI class allows instantiation of such a schema.

## JSI classes

A JSI class (that is, subclass of JSI::Base) is a starting point but obviously you want your own methods, so you reopen the class as you would any other. referring back to the Example section above, we reopen the Contact class:

```ruby
class Contact
  def full_address
    address.values.join(", ")
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
bill.instance['name']
# => "rob"
```

Note the use of `super` - you can call to accessors defined by JSI and make your accessors act as wrappers (these accessor methods are defined on an included module instead of the JSI class for this reason). You can also use [] and []=, of course, with the same effect.

If you want to add methods to a subschema, get the class_for_schema for that schema and open up that class. You can leave the class anonymous, as in this example:

```ruby
phone_schema = Contact.schema['properties']['phone']['items']
JSI.class_for_schema(phone_schema).class_eval do
  def number_with_dashes
    number.split(//).join('-')
  end
end
bill.phone.first.number_with_dashes
# => "5-5-5"
```

If you want to name the class, this works:

```ruby
Phone = JSI.class_for_schema(Contact.schema['properties']['phone']['items'])
class Phone
  def number_with_dashes
    number.split(//).join('-')
  end
end
```

Either syntax is slightly cumbersome and a better syntax is in the works.

## ActiveRecord serialization

A really excellent place to use JSI is when dealing with serialized columns in ActiveRecord.

Let's say you're sticking to json types in the database - you have to do so if you're using json columns, or json serialization, and if you have dealt with arbitrary yaml- or marshal-serialized objects in ruby, you have probably found that approach has its shortcomings when the implementation of your classes changes.

But if your database contains json, then your deserialized objects in ruby are likewise Hash / Array / basic types. You have to use subscripts instead of accessors, and you don't have any way to add methods to your data types.

JSI gives you the best of both with SchemaInstanceJSONCoder. The objects in your database are simple json types, and your ruby classes are extensible and have the accessors you get from a JSI class hierarchy. Here's an example:

```ruby
class User < ActiveRecord::Base
  serialize :contacts, JSI::SchemaInstanceJSONCoder.new(Contact, array: true)
end
```

Now `user.contacts` will return an array of Contact instances, from the json type in the database, with Contact's accessors, validations, and user-defined instance methods.

## Keying Hashes (JSON Objects)

Unlike Ruby, JSON only supports string keys. JSI converts symbols to strings for its internal hash keys (much like ActiveSupport::HashWithIndifferentAccess). JSI accepts symbols to refer to its string hash keys for instantiation, but does not currently transform symbols to strings everywhere else, e.g. `bill[:name]` is `nil` whereas `bill['name']` is `"bill"`.

## Contributing

Issues and pull requests are welcome on GitHub at https://github.com/notEthan/jsi.

## License

JSI is open source software available under the terms of the [MIT License](https://opensource.org/licenses/MIT).
