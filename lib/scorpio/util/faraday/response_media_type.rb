require 'api_hammer'

# hax
class Faraday::Response
  def media_type
    content_type_attrs.media_type
  end
  def content_type_attrs
    ApiHammer::ContentTypeAttrs.new(content_type)
  end
  def content_type
    _, ct = env.response_headers.detect { |k,v| k =~ /\Acontent[-_]type\z/i }
    ct
  end
end
