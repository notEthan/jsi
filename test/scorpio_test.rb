require 'test_helper'

class ScorpioTest < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::Scorpio::VERSION
  end
end

describe 'blog' do
  it 'indexes articles' do
    Blog::Article.create!(title: "sports")

    articles = Article.index

    assert_equal(1, articles.size)
    article = articles[0]
    assert_equal(1, article['id'])
    assert(article.is_a?(Article))
    assert_equal('sports', article['title'])
  end
end
