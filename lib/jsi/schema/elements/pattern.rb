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
          if instance.respond_to?(:to_str)
            begin
              # This string SHOULD be a valid regular expression, according to the ECMA 262 regular expression
              # dialect.
              # TODO
              regexp = Regexp.new(value)
              #> A string instance is considered valid if the regular expression matches the instance successfully.
              validate(
                regexp.match(instance),
                'validation.keyword.pattern.not_match',
                'instance string does not match `pattern` regular expression value',
                keyword: 'pattern',
              )
            rescue RegexpError
              # cannot validate
            end
          end
        end
      end
        end # element.add_action(:validate)
      end # Schema::Element.new
    end # PATTERN = element_map
  end # module Schema::Elements
end
