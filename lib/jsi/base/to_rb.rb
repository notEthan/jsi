module JSI
  class Base
    class << self
      def class_comment
        lines = []

        description = schema &&
          schema['description'].respond_to?(:to_str) &&
          schema['description'].to_str
        if description
          description.split("\n", -1).each do |descline|
            lines << "# " + descline
          end
          lines << "#"
        end

        schema.described_object_property_names.each_with_index do |propname, i|
          lines << "#" unless i == 0
          lines << "# @!attribute [rw] #{propname}"

          property_schema = schema['properties'].respond_to?(:to_hash) &&
            schema['properties'][propname].respond_to?(:to_hash) &&
            schema['properties'][propname]

          required = property_schema && property_schema['required']
          required ||= schema['required'].respond_to?(:to_ary) && schema['required'].include?(propname)
          lines << "#   @required" if required

          type = property_schema &&
            property_schema['type'].respond_to?(:to_str) &&
            property_schema['type'].to_str
          simple = {'string' => 'String', 'number' => 'Numeric', 'boolean' => 'Boolean', 'null' => 'nil'}
          rettypes = []
          if simple.key?(type)
            rettypes << simple[type]
          elsif type == 'object' || type == 'array'
            rettypes = []
            schema_class = JSI.class_for_schema(property_schema)
            unless schema_class.name =~ /\AJSI::SchemaClasses::/
              rettypes << schema_class.name
            end
            rettypes << {'object' => '#to_hash', 'array' => '#to_ary'}[type]
          elsif type
            # not really valid, but there's some information in there. whatever it is.
            rettypes << type
          end
          # we'll add Object to all because the accessor methods have no enforcement that their value is
          # of the specified type, and may return anything really. TODO: consider if this is of any value?
          rettypes << 'Object'
          lines << "#   @return [#{rettypes.join(', ')}]"

          description = property_schema &&
            property_schema['description'].respond_to?(:to_str) &&
            property_schema['description'].to_str
          if description
            description.split("\n", -1).each do |descline|
              lines << "#     " + descline
            end
          end
        end
        lines.join("\n")
      end

      def to_rb
        lines = []
        description = schema &&
          schema['description'].respond_to?(:to_str) &&
          schema['description'].to_str
        if description
          description.split("\n", -1).each do |descline|
            lines << "# " + descline
          end
        end
        lines << "class #{name}"
        schema.described_object_property_names.each_with_index do |propname, i|
          lines << "" unless i == 0
          property_schema = schema['properties'].respond_to?(:to_hash) &&
            schema['properties'][propname].respond_to?(:to_hash) &&
            schema['properties'][propname]
          description = property_schema &&
            property_schema['description'].respond_to?(:to_str) &&
            property_schema['description'].to_str
          if description
            description.split("\n", -1).each do |descline|
              lines << "  # " + descline
            end
            lines << "  #" # blank comment line between description and @return
          end

          required = property_schema && property_schema['required']
          required ||= schema['required'].respond_to?(:to_ary) && schema['required'].include?(propname)
          lines << "  # @required" if required

          type = property_schema &&
            property_schema['type'].respond_to?(:to_str) &&
            property_schema['type'].to_str
          simple = {'string' => 'String', 'number' => 'Numeric', 'boolean' => 'Boolean', 'null' => 'nil'}
          rettypes = []
          if simple.key?(type)
            rettypes << simple[type]
          elsif type == 'object' || type == 'array'
            rettypes = []
            schema_class = JSI.class_for_schema(property_schema)
            unless schema_class.name =~ /\AJSI::SchemaClasses::/
              rettypes << schema_class.name
            end
            rettypes << {'object' => '#to_hash', 'array' => '#to_ary'}[type]
          elsif type
            # not really valid, but there's some information in there. whatever it is.
            rettypes << type
          end
          # we'll add Object to all because the accessor methods have no enforcement that their value is
          # of the specified type, and may return anything really. TODO: consider if this is of any value?
          rettypes << 'Object'
          lines << "  # @return [#{rettypes.join(', ')}]"

          lines << "  def #{propname}"
          lines << "    super"
          lines << "  end"
        end
        lines << "end"
        lines.join("\n")
      end
    end
  end
end
