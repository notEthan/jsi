# this is a virtual model to parent models representing resources of the blog. it sets
# up connection information including base url, custom middleware or adapter for faraday.
# it describes the API by setting the API document, but this class itself represents no
# resources - it sets no resource_name and defines no schema_keys.
class BlogModel < Scorpio::Model
  self.base_url = 'https://blog.example.com/'
  set_openapi_document(Scorpio::Google::RestDescription.new(YAML.load_file('test/blog_description.yml')).to_openapi_document)
  self.faraday_request_middleware = [[:api_hammer_request_logger, Blog.logger]]
  self.faraday_adapter = [:rack, Blog.new]
end

# this is a model of Article, a resource of the blog API. it sets the resource_name
# to the key of the 'resources' section of the API (described by the api document
# specified to BlogModel) 
class Article < BlogModel
  self.resource_name = 'articles'
  self.definition_keys = ['articles']
end
