# this is a virtual model to parent models representing resources of the blog. it sets
# up connection information including base url, custom middleware or adapter for faraday.
# it describes the API by setting the API document, but this class itself represents no
# resources - it sets no resource_name and defines no schema_keys.
class BlogModel < Scorpio::Model
  set_openapi_document(YAML.load_file('test/blog.openapi.yml'))
  self.base_url = File.join('https://blog.example.com/', openapi_document.basePath)
  self.faraday_request_middleware = [[:api_hammer_request_logger, Blog.logger]]
  self.faraday_adapter = [:rack, Blog.new]
end

# this is a model of Article, a resource of the blog API. it sets the resource_name
# to the key of the 'resources' section of the API (described by the api document
# specified to BlogModel) 
class Article < BlogModel
  self.tag_name = 'articles'
  self.definition_keys = ['articles']
end
