# frozen_string_literal: true

require "json-schema"

# apply the changes from https://github.com/ruby-json-schema/json-schema/pull/382 

# json-schema/validator.rb

module JSON
  class Validator
    def initialize(schema_data, data, opts={})
      @options = @@default_opts.clone.merge(opts)
      @errors = []

      validator = self.class.validator_for_name(@options[:version])
      @options[:version] = validator
      @options[:schema_reader] ||= self.class.schema_reader

      @validation_options = @options[:record_errors] ? {:record_errors => true} : {}
      @validation_options[:insert_defaults] = true if @options[:insert_defaults]
      @validation_options[:strict] = true if @options[:strict] == true
      @validation_options[:clear_cache] = true if !@@cache_schemas || @options[:clear_cache]

      @@mutex.synchronize { @base_schema = initialize_schema(schema_data) }
      @original_data = data
      @data = initialize_data(data)
      @@mutex.synchronize { build_schemas(@base_schema) }

      # If the :fragment option is set, try and validate against the fragment
      if opts[:fragment]
        @base_schema = schema_from_fragment(@base_schema, opts[:fragment])
      end

      # validate the schema, if requested
      if @options[:validate_schema]
        if @base_schema.schema["$schema"]
          base_validator = self.class.validator_for_name(@base_schema.schema["$schema"])
        end
        metaschema = base_validator ? base_validator.metaschema : validator.metaschema
        # Don't clear the cache during metaschema validation!
        self.class.validate!(metaschema, @base_schema.schema, {:clear_cache => false})
      end
    end

    def schema_from_fragment(base_schema, fragment)
      schema_uri = base_schema.uri

      pointer = JSI::JSON::Pointer.from_fragment(fragment)

      base_schema = JSON::Schema.new(pointer.evaluate(base_schema.schema), schema_uri, @options[:version])

      if @options[:list]
        base_schema.to_array_schema
      elsif base_schema.is_a?(Hash)
        JSON::Schema.new(base_schema, schema_uri, @options[:version])
      else
        base_schema
      end
    end
  end
end
