#!/usr/bin/env ruby

require 'pathname'
require 'json'
require 'yaml'
Pathname.glob('documents/**/*').select { |p| p.file? && !['.yml', '.yaml'].include?(p.extname) }.each do |file|
  begin
    json_contents = JSON.parse(file.read)
    yaml = YAML.dump(json_contents, line_width: -1)
    yaml_filepath = Pathname.new(file.to_path.chomp('.json') + '.yml')
    if yaml_filepath.exist?
      contents = yaml_filepath.read
      if contents == yaml
        puts "#{yaml_filepath.to_path} unchanged"
      else
        yaml_filepath.write(yaml)
        puts "#{yaml_filepath.to_path} changed; updated"
      end
    else
      yaml_filepath.write(yaml)
      puts "#{yaml_filepath.to_path} created"
    end
  rescue JSON::ParserError
    puts "#{file.to_path}: not json"
  end
end
