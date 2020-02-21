# frozen_string_literal: true

module JSI
  module Validation
    autoload :Result, 'jsi/validation/result'
    autoload :FullResult, 'jsi/validation/result'
    autoload :ValidityResult, 'jsi/validation/result'

    VALID = ValidityResult.new(true).freeze

    INVALID = ValidityResult.new(false).freeze
  end
end
