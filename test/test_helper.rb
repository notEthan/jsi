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
  def assert_equal exp, act, msg = nil
    msg = message(msg, E) { diff exp, act }
    assert exp == act, msg
  end
end

# register this to be the base class for specs instead of Minitest::Spec
Minitest::Spec.register_spec_type(//, JSISpec)

# tests support of things that duck-type #to_hash
class SortOfHash
  def initialize(hash)
    @hash = hash
  end
  def to_hash
    @hash
  end
  include JSI::FingerprintHash
  def fingerprint
    {class: self.class, hash: @hash}
  end
end

# tests support of things that duck-type #to_ary
class SortOfArray
  def initialize(ary)
    @ary = ary
  end
  def to_ary
    @ary
  end
  include JSI::FingerprintHash
  def fingerprint
    {class: self.class, ary: @ary}
  end
end
