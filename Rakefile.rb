# frozen_string_literal: true

namespace 'test' do
  require "rake/testtask"

  Rake::TestTask.new('unit') do |t|
    t.libs << "test"
    t.test_files = FileList["test/*_test.rb"]
    t.verbose = true
    t.warning = true
  end
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
