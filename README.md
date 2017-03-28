# Scorpio

Scorpio is a library intended to make use of the API description document format defined for Google's API discovery service for various purposes. 

For background on the Google discovery service and the API description format it defines, see:

- https://developers.google.com/discovery/
- https://developers.google.com/discovery/v1/reference/

This document defines schemas using the JSON schema specification: http://json-schema.org/

## Scorpio::Model

Scorpio::Model aims to represent RESTful resources in ruby classes with as little code as possible, given a service with a properly constructed API description.

A model representing a resource needs to be configured, minimally, with:

- the API description for the REST API
- the base URL where the service is deployed, relative to which are the paths of the API description
- the schema(s) the model represents

If the resource has HTTP methods associated with it (most, but not all resources will):

- the name of the resource corresponding to the model

When these are set, Scorpio::Model looks through the API description and dynamically sets up methods for the model:

- accessors for properties of the model defined as properties of schemas representing the resource in the description
- API method calls on the model class and, where appropriate, on the model instance

### Example: Blog

Scorpio's tests are a good place to read example code of an API

The Blog service is defined in test/blog.rb. It uses ActiveRecord models and Sinatra to make a simple RESTful service.

Its API is described in `test/blog_description.yml`, defining the Article resource, several methods (some of which are instance methods), and schemas.

The client is set up in `test/blog_scorpio_models.rb`. The base class BlogModel defines the base_url and the api description, as well as some other optional setup done for testing.

The Article model inherits from BlogModel and is set with its resource name and the keys of its schema in the API description.

Based on those, Article gets the methods of the API description which are tested in `test/scorpio_test.rb`.

[This section will be fleshed out with more description and less just telling you, dear reader, to read the test code, as development progresses.]

### Scorpio Model pickle adapter

Scorpio provides a pickle adapter to use models with [Pickle](https://rubygems.org/gems/pickle). `require 'scorpio/pickle_adapter'`, ensure that the pickle ORM adapter is enabled, and you should be able to create models as normal with pickle.

## Other

The detailed, machine-interpretable description of an API provided by a properly-constructed API description document opens up numerous possibilities to automate aspects of clients and services to an API. These are planned to be implemented in Scorpio:

- generating human-readable HTML documentation for an API
- constructing test objects in a manner similar to FactoryGirl, allowing you to write tests that depend on a service without having to interact with an actual running instance of that service to run your tests
- rack middleware to test that outgoing HTTP responses are conformant to their response schemas
- rack middleware to test that incoming HTTP requests are conformant to their request schemas, and that the service handles bad requests appropriately (e.g. ensuring that for any bad request, the service responds with a 4xx error instead of 2xx).
- integrating with ORMs to generate HTTP responses that are conformant to the response schema corresponding to the resource corresponding to the ORM model
- generating model validations for ORMs

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

