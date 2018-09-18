require 'coveralls'
if Coveralls.will_run?
  Coveralls.wear!
end

require 'simplecov'
$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'jsi'

# NO EXPECTATIONS
ENV["MT_NO_EXPECTATIONS"] = ''

require 'minitest/autorun'
require 'minitest/around/spec'
require 'minitest/reporters'

Minitest::Reporters.use! Minitest::Reporters::SpecReporter.new

require 'byebug'

class JSISpec < Minitest::Spec
  if ENV['JSI_TEST_ALPHA']
    # :nocov:
    define_singleton_method(:test_order) { :alpha }
    # :nocov:
  end

  def assert_equal exp, act, msg = nil
    msg = message(msg, E) { diff exp, act }
    assert exp == act, msg
  end
end

# register this to be the base class for specs instead of Minitest::Spec
Minitest::Spec.register_spec_type(//, JSISpec)
