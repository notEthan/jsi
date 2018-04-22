require 'coveralls'
if Coveralls.will_run?
  Coveralls.wear!
end

require 'simplecov'
$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'scorpio'

# NO EXPECTATIONS 
ENV["MT_NO_EXPECTATIONS"] = ''

require 'minitest/autorun'
require 'minitest/around/spec'
require 'minitest/reporters'

Minitest::Reporters.use! Minitest::Reporters::SpecReporter.new

require 'faraday'
require 'scorpio/util/faraday/response_media_type'

require_relative 'blog'
require_relative 'blog_scorpio_models'

require 'database_cleaner'
# DatabaseCleaner.clean_with(:truncation) # don't need this as long as the database is in-memory
class ScorpioSpec < Minitest::Spec
  around do |test|
    DatabaseCleaner.cleaning { test.call }
  end

  def assert_equal exp, act, msg = nil
    msg = message(msg, E) { diff exp, act }
    assert exp == act, msg
  end
end

# register this to be the base class for specs instead of Minitest::Spec
Minitest::Spec.register_spec_type(//, ScorpioSpec)
