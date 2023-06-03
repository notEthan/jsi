# frozen_string_literal: true

namespace 'test' do
  require "rake/testtask"
  require "ansi/code"

  class JSITestTask < Rake::TestTask
    def initialize(name: , title: , description: nil, pattern: nil, test_files: nil, env: {})
      @title = title
      @env = {}
      @env['JSI_TEST_TASK'] = "test:#{name}"
      @env['JSI_TESTREPORT'] = 'progress' if !ENV['JSI_TESTREPORT'] && !ENV['CI']
      @env.update(env)
      super(name) do |t|
        t.description = description
        t.pattern = pattern
        t.test_files = test_files
        t.verbose = true
        t.warning = true
      end
    end

    # hack in some things
    # - print task title
    # - support @env hash
    # method #ruby isn't the right entry point for these, but there isn't a better one
    # overrides #ruby defined on FileUtils in rake/file_utils.rb
    # that #ruby handles more params but Rake::TestTask only calls it with one ruby command args string + block
    def ruby(cmd_args, &block)
      puts
      puts "#{ANSI::Code.magenta('𐡷')} #{ANSI::Code.cyan(@title.upcase)} #{ANSI::Code.magenta('𐡸')}"
      puts

      sh(@env, "#{RUBY} #{cmd_args}", &block)
    end
  end

  JSITestTask.new(
    name: 'unit',
    title: 'unit tests',
    description: 'run JSI unit tests',
    pattern: "test/*_test.rb",
  )

  JSITestTask.new(
    name: 'jsts',
    title: 'JSON Schema Test Suite',
    description: 'run tests from the JSON Schema Test Suite',
    pattern: "test/json_schema_test_suite/*_test.rb",
  )

  # tests which rely on libraries jsi does not itself depend on are run separately.
  # if code is added to JSI which inadvertantly relies on these, and the tests require that dependency,
  # then tests might pass when applications without that dependency would fail.
  # the JSI_TEST_EXTDEP variable causes the :extdep bundler group in the Gemfile to be set up.
  JSITestTask.new(
    name: 'extdep',
    title: 'external dependencies',
    description: 'run tests which rely on libraries JSI does not itself depend on',
    pattern: "test/extdep/*_test.rb",
    env: {'JSI_TEST_EXTDEP' => 'y'},
  )
end

desc 'run all tests'
task 'test' => [
  'test:unit',
  'test:jsts',
  'test:extdep'
]

task 'default' => 'test:unit'

require 'gig'

ignore_files = %w(
  .github/**/*
  .gitignore
  .gitmodules
  bin/c
  Gemfile
  Rakefile.rb
  test/**/*
  \\{resources\\}/icons/**/*
  \\{resources\\}/test/**/*
).map { |glob| Dir.glob(glob, File::FNM_DOTMATCH) }.inject([], &:|)
Gig.make_task(gemspec_filename: 'jsi.gemspec', ignore_files: ignore_files)
