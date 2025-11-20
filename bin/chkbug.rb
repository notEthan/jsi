#!/usr/bin/env ruby

enable = true
ARGV.each { |a| enable = (a == '-' ? false : a == '+' ? true : abort("unrecognized ARGV = #{ARGV.inspect}")) }

require_relative "../test/jsi_helper"
gemspec_filename = JSI::ROOT_PATH.join('jsi.gemspec')
spec = Gem::Specification.load(gemspec_filename.to_path) || abort("gemspec did not load: #{gemspec_filename}")
rbpaths = spec.files.map { |f| Pathname.new(f) }.select { |p| p.extname == '.rb' }
rbpaths.each do |p|
  ls = p.read.split("\n", -1)
  changed = false
  newls = ls.map do |l|
    if enable && (m = l.match(/\A(\s*)#chkbug ( *)(.*)\z/))
      changed = true
      "#{m[1]}#{m[2]}#{m[3]} #chkbug#{m[2]}"
    elsif !enable && (m = l.match(/\A(\s*)( *)(.*) #chkbug\2\z/))
      changed = true
      "#{m[1]}#chkbug #{m[2]}#{m[3]}"
    else
      l
    end
  end
  if changed
    puts("#{enable ? '+' : '-'} #{p}")
    p.open('w') { |f| f.write(newls.join("\n")) }
  end
end
