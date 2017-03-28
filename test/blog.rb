require 'sinatra'
require 'api_hammer'
require 'rack/accept'
require 'logger'

# app

class Blog < Sinatra::Base
  include ApiHammer::Sinatra
  self.supported_media_types = ['application/json']
  set :static, false
  disable :protection
  set :logger, ::Logger.new(STDOUT)
  logger.level = ::Logger::WARN
  define_method(:logger) { self.class.logger }
  use_with_lint ApiHammer::RequestLogger, logger
end

# models

require 'active_record'
ActiveRecord::Base.logger = Blog.logger
ActiveRecord::Base.establish_connection(
  :adapter => "sqlite3",
  :database  => ":memory:"
)

ActiveRecord::Schema.define do
  create_table :articles do |table|
    table.column :title, :string
    table.column :author_id, :integer
  end

  create_table :authors do |table|
    table.column :name, :string
  end
end

# we will namespace the models under Blog so that the top-level namespace
# can be used by the scorpio model classes
class Blog
  class Article < ActiveRecord::Base
    # validates_enthusiasm_of :title
    validate { errors.add(:title, "with gusto!") if title && !title[/!\z/] }
  end
  class Author < ActiveRecord::Base
  end
end

# controllers

class Blog
  get '/v1/articles' do
    check_accept

    articles = Blog::Article.all
    format_response(200, articles.map(&:serializable_hash))
  end
  get '/v1/articles_with_root' do
    check_accept

    articles = Blog::Article.all
    body = {
      # this is on the response schema, an array with items whose id indicates they are articles
      'articles' => articles.map(&:serializable_hash),
      # in the response schema, a single article
      'best_article' => articles.last.serializable_hash,
      # this is on the response schema, not indicating it is an article
      'version' => 'v1',
      # this is not in the response schema at all
      'note' => 'hi!',
    }
    format_response(200, body)
  end
  get '/v1/articles/:id' do |id|
    article = find_or_halt(Blog::Article, id: id)
    format_response(200, article.serializable_hash)
  end
  post '/v1/articles' do
    article = Article.create(parsed_body)
    if article.persisted?
      format_response(200, article.serializable_hash)
    else
      halt_unprocessable_entity(article.errors.messages)
    end
  end
  patch '/v1/articles/:id' do |id|
    article_attrs = parsed_body
    article = find_or_halt(Blog::Article, id: id)

    article.assign_attributes(article_attrs)
    saved = article.save
    if saved
      format_response(200, article.serializable_hash)
    else
      halt_unprocessable_entity(article.errors.messages)
    end
  end
end
