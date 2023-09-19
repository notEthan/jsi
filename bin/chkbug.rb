#!/usr/bin/env ruby

require_relative "../test/jsi_helper"
gemspec_filename = JSI::ROOT_PATH.join('jsi.gemspec')
spec = Gem::Specification.load(gemspec_filename.to_path) || abort("gemspec did not load: #{gemspec_filename}")
rbpaths = spec.files.map { |f| Pathname.new(f) }.select { |p| p.extname == '.rb' }
rbpaths.each do |p|
  ls = p.read.split("\n", -1)
  changed = false
  newls = ls.map do |l|
    if (m = l.match(/\A(\s*)#chkbug (.*)\z/))
      changed = true
      m[1] + m[2] + " #chkbug"
    else
      l
    end
  end
  if changed
    puts "+ #{p}"
    p.open('w') { |f| f.write(newls.join("\n")) }
  end
end
