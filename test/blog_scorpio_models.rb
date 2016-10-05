class BlogModel < Scorpio::Model
  self.base_url = 'https://blog.example.com/'
  set_api_description(YAML.load_file('test/blog_description.yml'))
  self.faraday_request_middleware = [[:api_hammer_request_logger, Blog.logger]]
  self.faraday_adapter = [:rack, Blog.new]
end

class Article < BlogModel
  self.resource_name = 'articles'
  self.schema_keys = ['articles']
end
