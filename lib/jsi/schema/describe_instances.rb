module JSI
  class Schema
    module DescribeInstances
      def describe_instances(instances)
        Schema.new(object_describe_instances(instances))
      end
      def describe_instance(instance)
        describe_instances([instance])
      end
      def object_describe_instances(instances)
        {}.tap do |schema_object|
          if instances.all? { |i| i.respond_to?(:to_hash) }
            schema_object['type'] = 'object'
            keys = instances.map { |i| i.to_hash.keys }.inject(Set.new, &:|)
            unless keys.empty?
              schema_object['properties'] = {}
            end
            keys.each do |key|
              values = instances.select { |i| i.to_hash.key?(key) }.map { |i| i.to_hash[key] }
              schema_object['properties'][key] = object_describe_instances(values)
            end
          elsif instances.all? { |i| i.respond_to?(:to_ary) }
            schema_object['type'] = 'array'
            # TODO if all the arrays are the same length and schemas to describe each index
            # look better, use that. make it configurable maybe.
            schema_object['items'] = object_describe_instances(instances.map(&:to_ary).inject(Set.new, &:|))
          elsif instances.all? { |i| i.respond_to?(:to_str) }
            schema_object['type'] = 'string'
            if instances.all? { |i| i =~ /\A(\{)?([a-fA-F0-9]{4}-?){8}(?(1)\}|)\z/ }
              schema_object['format'] = 'uuid'
            elsif instances.all? { |i| i =~ /\A(?<year>-?(?:[1-9][0-9]*)?[0-9]{4})-(?<month>1[0-2]|0[1-9])-(?<day>3[0-1]|0[1-9]|[1-2][0-9])T(?<hour>2[0-3]|[0-1][0-9]):(?<minute>[0-5][0-9]):(?<second>[0-5][0-9])(?<ms>\.[0-9]+)?(?<timezone>Z|[+-](?:2[0-3]|[0-1][0-9]):[0-5][0-9])?\z/ }
              schema_object['format'] = 'date-time'
            end
          elsif instances.all? { |i| i.is_a?(Integer) }
            schema_object['type'] = 'integer'
          elsif instances.all? { |i| i.is_a?(Numeric) }
            schema_object['type'] = 'number'
          elsif instances.all? { |i| [true, false].include?(i) }
            schema_object['type'] = 'boolean'
          elsif instances.all?(&:nil?)
            schema_object['type'] = 'null'
          end
        end
      end
    end
  end
end
