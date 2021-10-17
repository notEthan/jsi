# frozen_string_literal: true

require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/**/*_test.rb"]
end

task :default => :test

JSI_GEM_IGNORE_FILES = %w(
  .gitignore
  .gitmodules
  .travis.yml
  .simplecov
  Gemfile
  jsi.gemspec
  test/**/*
  \\{resources\\}/icons/**/*
  \\{resources\\}/test/**/*
).map { |glob| Dir.glob(glob, File::FNM_DOTMATCH) }.inject([], &:|)

task :gem do
  require 'shellwords'

  git_files = `git ls-files -z --recurse-submodules`.split("\x0")

  fs_files = Dir.glob('**/*', File::FNM_DOTMATCH).reject { |f| File.lstat(f).ftype == 'directory' }

  gemspec_filename = 'jsi.gemspec'
  spec = Gem::Specification.load(gemspec_filename)

  files = Set.new + git_files + fs_files + spec.files + spec.test_files

  file_errors = []
  file_error = -> (msg) {
    file_errors << msg
    puts msg
  }

  files.each do |file|
    in_git = git_files.include?(file)
    in_fs = fs_files.include?(file)
    in_spec = spec.files.include?(file) || spec.test_files.include?(file)

    if in_git
      if in_fs
        if in_spec
          git_status = `git status --porcelain #{Shellwords.escape(file)}`
          if git_status.empty?
            # pass. TODO: arX
          else
            file_error.("file modified from git: #{file}")
          end
        else
          if JSI_GEM_IGNORE_FILES.include?(file)
            # pass
          else
            file_error.("git file not in spec: #{file}")
          end
        end
      else
        file_error.("git file not in fs: #{file}")
      end
    else
      if in_spec
        file_error.("file in gemspec but not in git: #{file}")
      else
        # in fs but ignored by git and spec: pass
      end
    end
  end

  unless file_errors.empty?
    abort "aborting gem build due to file errors"
  end

  require 'rubygems/package'
  Gem::Package.build(spec)
end
