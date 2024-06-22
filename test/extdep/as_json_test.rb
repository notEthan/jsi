require_relative('../test_helper')

require("active_support")
require("active_support/core_ext/object/json")

describe('Base#as_json') do
  it("ActiveSupport's Object#as_json does not override Base") do
    hash_node = JSI::JSONSchemaDraft07.new_schema({"$id" => "tag:ms9g"}).new_jsi(SortOfHash.new({a: :b}))
    # since Base::HashNode includes Enumerable, and ActiveSupport infects Enumerable with a #as_json
    # method that returns an Array, this would be [["a", "b"]] without HashNode re-overriding #as_json.
    assert_equal({"a" => "b"}, hash_node.as_json)
    # HashNode does not override #to_json, ActiveSupport's #to_json is on a module it prepends
    # rather than includes on Enumerable and it behaves properly
    assert_equal(%q({"a":"b"}), hash_node.to_json)
  end
end
