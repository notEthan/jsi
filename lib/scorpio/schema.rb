module Scorpio
  class Schema
    def initialize(schema_node)
      @schema_node = schema_node
    end
    attr_reader :schema_node
    def describes_array?
      schema_node['type'] == 'array' ||
        schema_node['items'] ||
        schema_node['additionalItems'] ||
        schema_node['default'].respond_to?(:to_ary) || # TODO make sure this is right
        (schema_node['enum'].respond_to?(:to_ary) && schema_node['enum'].all? { |enum| enum.respond_to?(:to_ary) }) ||
        schema_node['maxItems'] ||
        schema_node['minItems'] ||
        schema_node.key?('uniqueItems') ||
        schema_node['oneOf'].respond_to?(:to_ary) &&
          schema_node['oneOf'].all? { |someof_node| self.class.new(someof_node).describes_array? } ||
        schema_node['allOf'].respond_to?(:to_ary) &&
          schema_node['allOf'].all? { |someof_node| self.class.new(someof_node).describes_array? } ||
        schema_node['anyOf'].respond_to?(:to_ary) &&
          schema_node['anyOf'].all? { |someof_node| self.class.new(someof_node).describes_array? }
    end
    def describes_hash?
      schema_node['type'] == 'object' ||
        schema_node['required'].respond_to?(:to_ary) ||
        schema_node['properties'].respond_to?(:to_hash) ||
        schema_node['additionalProperties'] ||
        schema_node['patternProperties'] ||
        schema_node['default'].respond_to?(:to_hash) ||
        (schema_node['enum'].respond_to?(:to_ary) && schema_node['enum'].all? { |enum| enum.respond_to?(:to_hash) }) ||
        schema_node['oneOf'].respond_to?(:to_ary) &&
          schema_node['oneOf'].all? { |someof_node| self.class.new(someof_node).describes_hash? } ||
        schema_node['allOf'].respond_to?(:to_ary) &&
          schema_node['allOf'].all? { |someof_node| self.class.new(someof_node).describes_hash? } ||
        schema_node['anyOf'].respond_to?(:to_ary) &&
          schema_node['anyOf'].all? { |someof_node| self.class.new(someof_node).describes_hash? }
    end
  end
end
