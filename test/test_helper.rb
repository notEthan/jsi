if ENV['CI'] || ENV['COV']
  require 'simplecov'
  SimpleCov.start do
    if ENV['CI']
      require 'simplecov-lcov'

      # TODO remove. see https://github.com/fortissimo1997/simplecov-lcov/pull/25
      if !SimpleCov.respond_to?(:branch_coverage)
        SimpleCov.define_singleton_method(:branch_coverage?) { false }
      end

      SimpleCov::Formatter::LcovFormatter.config do |c|
        c.report_with_single_file = true
        c.single_report_path = 'coverage/lcov.info'
      end

      formatter SimpleCov::Formatter::LcovFormatter
    else
      coverage_dir '{coverage}'
    end

    if ENV['JSI_TEST_TASK']
      command_name ENV['JSI_TEST_TASK']
    end
  end
end

require 'bundler'
bundler_groups = ENV['JSI_TEST_EXTDEP'] ? [:extdep, :default] : [:default]
Bundler.setup(*bundler_groups)

if !ENV['CI'] && Bundler.load.specs.any? { |spec| spec.name == 'byebug' }
  require 'byebug'
end

require_relative 'jsi_helper'

require 'yaml'

# NO EXPECTATIONS
ENV["MT_NO_EXPECTATIONS"] = ''

require 'minitest/autorun'
require 'minitest/around/spec'
require 'minitest/reporters'

module Minitest
  module WithEndSummary
    def report
      super
      skip_messages = results.select(&:skipped?).group_by { |r| r.failure.message }
      skip_messages.sort_by { |m, rs| [-rs.size, m] }.each do |msg, rs|
        puts "#{yellow("skipped #{rs.size}")}: #{msg}"
      end
      results.reject(&:skipped?).sort_by(&:source_location).each do |result|
        print(red(result.failure.is_a?(UnexpectedError) ? "error" : "failure"))
        print(": #{result.klass} #{result.name}")
        puts
        puts("  #{result.source_location.join(' :')}")
      end
    end
  end
end

mkreporters = {
  'spec' => -> {
    Minitest::Reporters::SpecReporter.new
  },
  'default' => -> {
    Minitest::Reporters::DefaultReporter.new(
      detailed_skip: false
    )
  },
  'progress' => -> {
    Minitest::Reporters::ProgressReporter.new(
      detailed_skip: false,
      format: '%e (%c/%C • %p%%) [%B]'
    )
  },
}

mkreporter = if ENV['JSI_TESTREPORT']
  mkreporters[ENV['JSI_TESTREPORT']] || raise("JSI_TESTREPORT must be one of: #{mkreporters.keys}")
elsif ENV['CI']
  mkreporters['spec']
else
  mkreporters['progress']
end

Minitest::Reporters.use!(mkreporter.call.extend(Minitest::WithEndSummary))
Minitest::Test.make_my_diffs_pretty!

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
    msg = message(msg) { "Expected object to be an instance of #{mod.inspect}. received #{obj.class}: #{mu_pp(obj)}" }

    assert obj.is_a?(mod), msg
  end

  def refute_is_a mod, obj, msg = nil
    msg = message(msg) { "Expected object not to be an instance of #{mod.inspect}. received #{obj.class}: #{mu_pp(obj)}" }

    assert !obj.is_a?(mod), msg
  end
end

# register this to be the base class for specs instead of Minitest::Spec
Minitest::Spec.register_spec_type(//, JSISpec)

Minitest.after_run do
  if ENV['JSI_EXITDEBUG']
    byebug
    nil
  end
end
