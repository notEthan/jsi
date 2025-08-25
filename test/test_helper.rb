test_t0 = Time.now
$test_report_time = proc do |msg|
  STDERR.puts "time %.4f: %s" % [Time.now - test_t0, msg] if ENV['COV']
end
$test_report_file_loaded = proc do |filename|
  $test_report_time["#{filename.sub(Regexp.new("\\A#{Regexp.escape(JSI::ROOT_PATH.to_s)}/"), "")} loaded"]
end
$test_report_time["starting"]

if ENV['CI'] || ENV['COV']
  require 'simplecov'
  SimpleCov.start do
    if ENV['CI']
      require 'simplecov-lcov'

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

require_relative 'jsi_helper'

# NO EXPECTATIONS
ENV["MT_NO_EXPECTATIONS"] = ''

require 'minitest/autorun'
require 'minitest/around/spec'
require 'minitest/reporters'
require('ansi/code')

module Minitest
  module WithEndSummary
    attr_reader :quiet

    def puts(*)
      super unless quiet
    end

    def print(*)
      super unless quiet
    end

    # @param sigfig [Integer] minimum number of digits to include (not including leading 0s) if duration < 1s
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

    def start
      $test_report_time["starting run"]
      super
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

      $test_report_time["finished run"]
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
else
  mkreporters['spec']
end

Minitest::Reporters.use!(mkreporter.call.extend(Minitest::WithEndSummary))
Minitest::Test.make_my_diffs_pretty!

class JSISpec < Minitest::Spec
  if ENV['JSI_TEST_ALPHA']
    # :nocov:
    define_singleton_method(:test_order) { :alpha }

    Minitest::Runnable.runnables.define_singleton_method(:shuffle) { self }
    # :nocov:
  end

  def self.schema_instance_child_use_default_default_true
    before { schema.jsi_schema_module_exec { redef_method(:jsi_child_use_default_default) { true } } }
  end

  def self.yaml(name, yaml)
    let(name) { JSI::DEFAULT_CONTENT_TO_IMMUTABLE[YAML.load(yaml)] }
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

  def assert_enum_equal(exp, act)
    assert_equal(exp.to_a, act.to_a)
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

  def assert_raises_msg(errclass, msg, &block)
    e = assert_raises(errclass, &block)
    assert_equal(msg, e.message)
  end

  def assert_frozen(object)
    assert_predicate(object, :frozen?)
  end

  def refute_frozen(object)
    refute_predicate(object, :frozen?)
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
    assert(instance.described_by?(schema))
  end

  # @param schema [JSI::Schema]
  # @param instance [JSI::Base]
  def refute_schema(schema, instance)
    JSI::Schema.ensure_schema(schema)

    assert_is_a(JSI::Base, instance)

    refute_includes(instance.jsi_schemas, schema)
    refute_is_a(schema.jsi_schema_module, instance)
    refute(instance.described_by?(schema))
  end

  def assert_consistent_jsi_descendent_errors(jsi, result: jsi.jsi_validate)
    result.each_validation_error do |result_error|
      # since the instance has an error at result_error.instance_ptr,
      # validation of the JSI descendent at that ptr should include that error,
      # as well as errors of its descendents.

      errors_below_instance_ptr = result.each_validation_error.select do |e|
        result_error.instance_ptr.ancestor_of?(e.instance_ptr)
      end.to_set

      descendent = jsi.jsi_descendent_node(result_error.instance_ptr)
      descendent_errors = descendent.jsi_validate.each_validation_error.to_set

      assert_equal(errors_below_instance_ptr, descendent_errors)
    end
  end

  def assert_uri(exp, act)
    assert_equal(JSI::Util.uri(exp), act)
    assert_predicate(act, :frozen?)
  end

  def assert_uris(exp, act)
    assert_equal(exp.map { |u| JSI::Util.uri(u) }, act.map { |u| JSI::Util.uri(u) })
    act.each { |u| assert_predicate(u, :frozen?) }
  end

  before do
    JSI.registry = JSI::DEFAULT_REGISTRY.dup
  end
end

# register this to be the base class for specs instead of Minitest::Spec
Minitest::Spec.register_spec_type(//, JSISpec)

Minitest.after_run do
  $test_report_time["Minitest.after_run"]

  if Object.const_defined?(:SimpleCov)
    counts = {}
    resultset = SimpleCov::ResultMerger.respond_to?(:read_resultset) ? SimpleCov::ResultMerger.read_resultset : SimpleCov::ResultMerger.resultset
    resultset.each do |command_name, result|
      if result['timestamp'] + SimpleCov.merge_timeout >= Time.now.to_i
        counts[command_name] = result['coverage'].each_value.map do |c|
          (c.is_a?(Hash) ? c['lines'] : c).compact.inject(0, &:+)
        end.inject(0, &:+)
      end
    end
    i_commas = -> (i) { i.to_s.reverse.gsub(/...(?=.)/, '\&,').reverse }
    if counts.size > 1 && counts.key?(SimpleCov.command_name)
      puts "Lines executed (#{SimpleCov.command_name}): #{i_commas[counts[SimpleCov.command_name]]}"
    end
    puts "Lines executed (#{counts.keys.join(' + ')}): #{i_commas[counts.each_value.inject(0, &:+)]}"
  end

  if ENV['JSI_EXITDEBUG']
    dbg
    nil
  end
end

$test_report_file_loaded[__FILE__]
