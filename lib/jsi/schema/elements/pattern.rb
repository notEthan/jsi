# frozen_string_literal: true

module JSI
  module Schema::Elements
    PATTERN = element_map do
      Schema::Element.new do |element|
        element.add_action(:validate) do
      if keyword?('pattern')
        value = schema_content['pattern']
        # The value of this keyword MUST be a string.
        if value.respond_to?(:to_str)
          if result_builder.instance.respond_to?(:to_str)
            begin
              # This string SHOULD be a valid regular expression, according to the ECMA 262 regular expression
              # dialect.
              # TODO
              regexp = Regexp.new(value)
              # A string instance is considered valid if the regular expression matches the instance
              # succssfully. Recall: regular expressions are not implicitly anchored.
              result_builder.validate(
                regexp.match(result_builder.instance),
                'instance string does not match `pattern` regular expression value',
                keyword: 'pattern',
              )
            rescue RegexpError => e
              result_builder.schema_error(-"`pattern` is not a valid regular expression: #{e.message}", 'pattern')
            end
          end
        else
          result_builder.schema_error('`pattern` is not a string', 'pattern')
        end
      end
        end # element.add_action(:validate)
      end # Schema::Element.new
    end # PATTERN = element_map
  end # module Schema::Elements
end
