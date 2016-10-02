class BlogModel < Scorpio::Model
  self.base_url = 'https://blog.example.com/'
  set_api_description(YAML.load_file('test/blog_description.yml'))
end

class Article < BlogModel
  self.resource_name = 'articles'
  self.schema_keys = ['articles']

  class << self
    def connection
      Faraday.new do |c|
        c.request :json
        c.request :api_hammer_request_logger, Blog.logger
        c.adapter :rack, Blog.new
        c.response :json, :content_type => /\bjson$/
      end
    end
  end
end
