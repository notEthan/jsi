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
  logpath = Pathname.new('log/test.log')
  FileUtils.mkdir_p(logpath.dirname)
  set :logger, ::Logger.new(logpath)
  logger.level = ::Logger::INFO
  define_method(:logger) { self.class.logger }
  use_with_lint ApiHammer::RequestLogger, logger

  # prevent sinatra from using Sinatra::ShowExceptions so we can use ShowTextExceptions instead
  set :show_exceptions, false
  # allow errors to bubble past sinatra up to ShowTextExceptions
  set :raise_errors, true
  # ShowTextExceptions rescues ruby exceptions and gives a response of 500 with text/plain
  use_with_lint ApiHammer::ShowTextExceptions, :full_error => true, :logger => logger
end

# models

require 'active_record'
ActiveRecord::Base.logger = Blog.logger
dbpath = Pathname.new('tmp/blog.sqlite3')
FileUtils.mkdir_p(dbpath.dirname)
dbpath.unlink if dbpath.exist?
ActiveRecord::Base.establish_connection(
  :adapter => "sqlite3",
  :database  => dbpath
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
    article = Blog::Article.create(parsed_body)
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

  require 'database_cleaner'
  post '/v1/clean' do
    DatabaseCleaner.clean_with(:truncation)
    format_response(200, nil)
  end
end
