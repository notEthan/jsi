class Article < Scorpio::Model
  class << self
    def connection
      Faraday.new(:url => 'https://blog.example.com') do |c|
        c.request :json
        c.request :api_hammer_request_logger, Blog.logger
        c.adapter :rack, Blog.new
        c.response :json, :content_type => /\bjson$/
      end
    end
    def index
      articles_resp = connection.get('/v1/articles')
      articles_resp.body.map do |attrs|
        new(attrs)
      end
    end
  end
end
