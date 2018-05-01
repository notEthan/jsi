require_relative 'test_helper'

class ScorpioTest < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::Scorpio::VERSION
  end
end

describe 'blog' do
  let(:blog_article) { Blog::Article.create!(title: "sports!") }

  it 'indexes articles' do
    blog_article

    articles = Article.index

    assert_equal(1, articles.size)
    article = articles[0]
    assert_equal(1, article['id'])
    assert(article.is_a?(Article))
    assert_equal('sports!', article['title'])
    assert_equal('sports!', article.title)
  end
  it 'indexes articles with root' do
    blog_article

    articles = Article.index_with_root
    assert_respond_to(articles, :to_hash)
    assert_equal('v1', articles['version'])
    assert_equal('hi!', articles['note'])
    assert_instance_of(Article, articles['best_article'])
    assert_equal(articles['articles'].last, articles['best_article'])
    assert_equal(1, articles['articles'].size)
    article = articles['articles'][0]
    assert_equal(1, article['id'])
    assert(article.is_a?(Article))
    assert_equal('sports!', article['title'])
    assert_equal('sports!', article.title)
  end
  it 'reads an article' do
    blog_article
    article = Article.read(id: blog_article.id)
    assert(article.is_a?(Article))
    assert_equal('sports!', article['title'])
    assert_equal('sports!', article.title)
  end
  it 'tries to read an article without a required path variable' do
    blog_article
    e = assert_raises(ArgumentError) do
      Article.read({})
    end
    assert_equal('path /articles/{id} for operation articles.read requires attributes which were missing: ["id"]',
      e.message)
    e = assert_raises(ArgumentError) do
      Article.read({id: ''})
    end
    assert_equal('path /articles/{id} for operation articles.read requires attributes which were empty: ["id"]',
      e.message)
  end
  it 'tries to read a nonexistent article' do
    err = assert_raises(Scorpio::NotFound404Error) do
      Article.read(id: 99)
    end
    assert_equal({"article" => ["Unknown article! id: 99"]}, err.response_object['errors'].as_json)
    assert_match(/Unknown article! id: 99/, err.message)
  end
  it 'updates an article on the class' do
    blog_article
    Article.patch({id: blog_article.id, title: 'politics!'})
    assert_equal('politics!', Article.read(id: blog_article.id).title)
  end
  it 'updates an article on the instance' do
    blog_article
    article = Article.read(id: blog_article.id)
    article.title = 'politics!'
    article.patch
    assert_equal('politics!', Article.read(id: blog_article.id).title)
  end
  it 'updates an article with an unsuccessful response' do
    blog_article
    err = assert_raises(Scorpio::UnprocessableEntity422Error) do
      Article.patch({id: blog_article.id, title: 'politics?'})
    end
    assert_equal({"title" => ["with gusto!"]}, err.response_object['errors'].as_json)
    assert_match(/with gusto!/, err.message)
    assert_equal('sports!', Article.read(id: blog_article.id).title)
  end
  it 'instantiates an article with bad argument' do
    assert_raises(ArgumentError) { Article.new("foo") }
  end
  it 'reports schema failure when the request does not match the request schema' do
    err = assert_raises(Scorpio::RequestSchemaFailure) do
      # title is supposed to be a string
      Article.post('title' => {'music' => '!'})
    end
  end
  it 'checks equality' do
    assert_equal(Article.read(id: blog_article.id), Article.read(id: blog_article.id))
  end
  it 'consistently keys a hash' do
    hash = {Article.read(id: blog_article.id) => 0}
    assert_equal(0, hash[Article.read(id: blog_article.id)])
  end
end
