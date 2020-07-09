#!/usr/bin/env ruby
# frozen_string_literal: true

# a small script following the code samples in the README

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), 'lib'))
require 'jsi'

puts "creating a schema and assigning its schema module to a constant"
puts

contact_schema = JSI::Schema.new({"description" => "A Contact", "type" => "object", "properties" => {"name" => {"type" => "string"}, "phone" => {"type" => "array", "items" => {"type" => "object", "properties" => {"location" => {"type" => "string"}, "number" => {"type" => "string"}}}}}})

print 'contact_schema: '
pp contact_schema

print 'contact_schema.jsi_schema_module: '
pp contact_schema.jsi_schema_module

puts "constant assignment: Contact = contact_schema.jsi_schema_module"
Contact = contact_schema.jsi_schema_module

print 'contact_schema.jsi_schema_module: '
pp contact_schema.jsi_schema_module

puts
puts "creating and using an instance described by the schema"
puts

bill = Contact.new_jsi({"name" => "bill", "phone" => [{"location" => "home", "number" => "555"}], "nickname" => "big b"})

print 'bill: '
pp bill

print 'bill.name: '
pp bill.name

print 'bill.phone.map(&:location): '
pp bill.phone.map(&:location)

print 'bill.validate: '
pp bill.validate

bad = Contact.new_jsi({'phone' => [{'number' => [5, 5, 5]}]})

print 'bad: '
pp bad

print 'bad.phone.fully_validate: '
pp bad.phone.fully_validate

print 'bill.transform_values(&:size): '
pp bill.transform_values(&:size)

print "bill['nickname']: "
pp bill['nickname']

puts
puts "OOP: application-defined methods on schema modules apply to their instances"
puts

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

print 'bill.name: '
pp bill.name

puts "bill.name = 'rob esq.'"
bill.name = 'rob esq.'

print "bill['name']: "
pp bill['name']

print 'bill.phone_numbers: '
pp bill.phone_numbers

puts
puts "OOP on subschemas"
puts

print "Contact.properties['phone'].items: "
pp Contact.properties['phone'].items

module Contact
  Phone = properties['phone'].items
  module Phone
    def number_with_dashes
      number.split(//).join('-')
    end
  end
end

print "Contact.properties['phone'].items: "
pp Contact.properties['phone'].items

print 'bill.phone.first.number_with_dashes: '
pp bill.phone.first.number_with_dashes
