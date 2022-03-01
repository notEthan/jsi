# frozen_string_literal: true

require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/**/*_test.rb"]
end

task :default => :test

require 'gig'

ignore_files = %w(
  .github/**/*
  .gitignore
  .gitmodules
  Gemfile
  jsi.gemspec
  Rakefile.rb
  test/**/*
  \\{resources\\}/icons/**/*
  \\{resources\\}/test/**/*
).map { |glob| Dir.glob(glob, File::FNM_DOTMATCH) }.inject([], &:|)
Gig.make_task(gemspec_filename: 'jsi.gemspec', ignore_files: ignore_files)
