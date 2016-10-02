require 'test_helper'

class ScorpioTest < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::Scorpio::VERSION
  end
end

describe 'blog' do
  let(:blog_article) { Blog::Article.create!(title: "sports") }

  it 'indexes articles' do
    blog_article

    articles = Article.index

    assert_equal(1, articles.size)
    article = articles[0]
    assert_equal(1, article['id'])
    assert(article.is_a?(Article))
    assert_equal('sports', article['title'])
    assert_equal('sports', article.title)
  end
  it 'reads an article' do
    blog_article
    article = Article.read(id: blog_article.id)
    assert(article.is_a?(Article))
    assert_equal('sports', article['title'])
    assert_equal('sports', article.title)
  end
  it 'tries to read an article without a required path variable' do
    blog_article
    e = assert_raises(ArgumentError) do
      Article.read({})
    end
    assert_equal('path v1/articles/{id} for method read requires attributes which were missing: ["id"]',
      e.message)
    e = assert_raises(ArgumentError) do
      Article.read({id: ''})
    end
    assert_equal('path v1/articles/{id} for method read requires attributes which were empty: ["id"]',
      e.message)
  end
end
