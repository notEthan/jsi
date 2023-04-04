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
bundler_groups = [:default, :test]
bundler_groups << :dev unless ENV['CI']
bundler_groups << :extdep if ENV['JSI_TEST_EXTDEP']
Bundler.setup(*bundler_groups)

if !ENV['CI'] && Bundler.load.specs.any? { |spec| spec.name == 'debug' }
  require 'debug'
  Object.alias_method(:dbg, :debugger)
  Object.alias_method(:byebug, :debugger) # TODO remove
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
    attr_reader :quiet

    def puts(*)
      super unless quiet
    end

    def print(*)
      super unless quiet
    end

    # @param sigfig [Integer] minimum number of digits to include (not including leading 0s if duration < 1s)
    def format_duration(duration, sigfig: 3)
      return('[negative duration]') if duration < 0 # duration should be positive, but nonmonotonic clock is possible

      lg = duration == 0 ? 0 : Math.log10(duration).floor
      if lg - sigfig + 1 < 0
        seconds = "%.#{sigfig - lg - 1}f" % (duration % 60)
      else
        seconds = "%i" % (duration % 60)
      end

      if duration > 60 * 60
        "%ih %im %ss" % [duration / 60 / 60, duration / 60 % 60, seconds]
      elsif duration > 60
        "%im %ss" % [duration / 60, seconds]
      else
        "%ss" % seconds
      end
    end

    def report
      @quiet = true
      super
      @quiet = false

      puts
      puts("Finished in #{format_duration(total_time)}")
      print('%d tests, %d assertions, ' % [count, assertions])
      color = failures.zero? && errors.zero? ? :green : :red
      print(send(color, '%d failures, %d errors, ' % [failures, errors]))
      print(yellow('%d skips' % skips))
      puts

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

  class JSISpecReporter < Minitest::Reporters::SpecReporter
    def record_print_status(test)
      test_name = test.name.gsub(/^test_(: |\d+_)/, '')
      print pad_test(test_name)
      print_colored_status(test)
      print(" (#{format_duration(test.time, sigfig: 2)})") unless test.time.nil?
      puts
    end
  end
end

mkreporters = {
  'spec' => -> {
    Minitest::JSISpecReporter.new
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

  # @param schemas [Enumerable<JSI::Schema>]
  # @param instance [JSI::Base]
  def assert_schemas(schemas, instance)
    schemas = JSI::SchemaSet.new(schemas)

    assert_is_a(JSI::Base, instance)

    assert_equal(schemas, instance.jsi_schemas)
    schemas.each do |schema|
      assert_is_a(schema.jsi_schema_module, instance)
    end
  end

  # @param schema [JSI::Schema]
  # @param instance [JSI::Base]
  def assert_schema(schema, instance)
    JSI::Schema.ensure_schema(schema)

    assert_is_a(JSI::Base, instance)

    assert_includes(instance.jsi_schemas, schema)
    assert_is_a(schema.jsi_schema_module, instance)
  end

  # @param schema [JSI::Schema]
  # @param instance [JSI::Base]
  def refute_schema(schema, instance)
    JSI::Schema.ensure_schema(schema)

    assert_is_a(JSI::Base, instance)

    refute_includes(instance.jsi_schemas, schema)
    refute_is_a(schema.jsi_schema_module, instance)
  end

  def assert_uri(exp, act)
    assert_equal(JSI::Util.uri(exp), act)
    assert_predicate(act, :frozen?)
  end
end

# register this to be the base class for specs instead of Minitest::Spec
Minitest::Spec.register_spec_type(//, JSISpec)

Minitest.after_run do
  if ENV['JSI_EXITDEBUG']
    dbg
    nil
  end
end
