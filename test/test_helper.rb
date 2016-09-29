$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'scorpio'

# NO EXPECTATIONS 
ENV["MT_NO_EXPECTATIONS"] = ''

require 'minitest/autorun'
require 'minitest/around/spec'
require 'minitest/reporters'

require 'faraday'
require 'faraday_middleware'

Minitest::Reporters.use! Minitest::Reporters::SpecReporter.new

require_relative 'blog'
require_relative 'blog_scorpio_models'
