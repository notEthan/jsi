# frozen_string_literal: true

module JSI
  module Validation
    autoload :Error, 'jsi/validation/error'
    autoload :Result, 'jsi/validation/result'

    INVALID = Result::Invalid.new.freeze
  end
end
