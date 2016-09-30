class Article < Scorpio::Model
  self.resource_name = 'articles'

  load_schema_ymls('test/blog_description.yml')

  class << self
    def connection
      Faraday.new(:url => 'https://blog.example.com') do |c|
        c.request :json
        c.request :api_hammer_request_logger, Blog.logger
        c.adapter :rack, Blog.new
        c.response :json, :content_type => /\bjson$/
      end
    end
  end
end
