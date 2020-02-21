require 'coveralls'
if Coveralls.will_run?
  Coveralls.wear!
end
require 'simplecov'

require 'bundler/setup'

require 'byebug'

$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'jsi'

# NO EXPECTATIONS
ENV["MT_NO_EXPECTATIONS"] = ''

require 'minitest/autorun'
require 'minitest/around/spec'
require 'minitest/reporters'

Minitest::Reporters.use! Minitest::Reporters::SpecReporter.new

class JSISpec < Minitest::Spec
  if ENV['JSI_TEST_ALPHA']
    # :nocov:
    define_singleton_method(:test_order) { :alpha }
    # :nocov:
  end

  def assert_equal exp, act, msg = nil
    msg = message(msg, E) do
      [].tap do |ms|
        ms << diff(exp, act)
        ms << "#{ANSI.red   { 'expected' }}: #{exp.inspect}"
        ms << "#{ANSI.green { 'actual' }}:   #{act.inspect}"
        if exp.respond_to?(:to_str) && act.respond_to?(:to_str)
          ms << "#{ANSI.red { 'expected (str)' }}:"
          ms << exp
          ms << "#{ANSI.green { 'actual (str)' }}:"
          ms << act
        end
      end.join("\n")
    end
    assert exp == act, msg
  end

  def assert_match matcher, obj, msg = nil
    msg = message(msg) do
      [].tap do |ms|
        ms << "Expected match."
        ms << "#{ANSI.red   { 'matcher' }}: #{mu_pp matcher}"
        ms << "#{ANSI.green { 'object' }}:  #{mu_pp obj}"
        ms << "#{ANSI.yellow { 'escaped' }}: #{Regexp.new(Regexp.escape(obj)).inspect}" if obj.is_a?(String)
      end.join("\n")
    end
    assert_respond_to matcher, :"=~"
    matcher = Regexp.new Regexp.escape matcher if String === matcher
    assert matcher =~ obj, msg
  end

  def assert_is_a mod, obj, msg = nil
    msg = message(msg) { "Expected instance of #{mod}. received #{obj.class}: #{mu_pp(obj)}" }

    assert obj.is_a?(mod), msg
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
  include JSI::Util::FingerprintHash
  def jsi_fingerprint
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
  include JSI::Util::FingerprintHash
  def jsi_fingerprint
    {class: self.class, ary: @ary}
  end
end
