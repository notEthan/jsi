# frozen_string_literal: true

namespace 'test' do
  require "rake/testtask"
  require "ansi/code"

  class JSITestTask < Rake::TestTask
    def initialize(name: , title: , description: nil, pattern: nil, test_files: nil)
      @title = title
      super(name) do |t|
        t.description = description
        t.pattern = pattern
        t.test_files = test_files
        t.verbose = true
        t.warning = true
      end
    end

    # I want a title printed. #ruby isn't the right entry point for this, but there isn't a better one
    def ruby(*)
      puts
      puts "#{ANSI::Code.magenta('𐡷')} #{ANSI::Code.cyan(@title.upcase)} #{ANSI::Code.magenta('𐡸')}"
      puts

      super
    end
  end

  JSITestTask.new(
    name: 'unit',
    title: 'unit tests',
    description: 'run JSI unit tests',
    pattern: "test/*_test.rb",
  )
end

desc 'run all tests'
task 'test' => [
  'test:unit',
]

task :default => :test

require 'gig'

ignore_files = %w(
  .github/**/*
  .gitignore
  .gitmodules
  Gemfile
  Rakefile.rb
  test/**/*
  \\{resources\\}/icons/**/*
  \\{resources\\}/test/**/*
).map { |glob| Dir.glob(glob, File::FNM_DOTMATCH) }.inject([], &:|)
Gig.make_task(gemspec_filename: 'jsi.gemspec', ignore_files: ignore_files)
