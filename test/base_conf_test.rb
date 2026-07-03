require_relative('test_helper')

describe("Base::Conf") do
  let(:metaschema) { JSI::JSONSchemaDraft07 }
  let(:schema) { JSI.new_schema(schema_content, default_metaschema: metaschema) }
  let(:schema_content) { {} }

  describe("Base::Conf / new_jsi") do
    it("returns a Base::Conf; it instantiates") do
      assert_instance_of(JSI::Base::Conf, schema.new_jsi)
      assert_is_a(JSI::Base, schema.new_jsi[{}])
    end

    describe("behavior according to instantiator member values") do
      it("root_indicated_schemas") do
        assert_equal(JSI::SchemaSet[schema], schema.new_jsi.root_indicated_schemas)
        assert_equal(JSI::SchemaSet[schema], schema.new_jsi[{}].jsi_indicated_schemas)
        # they can be overridden as currently implemented. no reason one ever would do this.
        assert_equal(JSI::SchemaSet[], schema.new_jsi.merge(root_indicated_schemas: JSI::SchemaSet[])[{}].jsi_indicated_schemas)
      end

      it("base_uri") do
        # default value
        assert_equal(nil, schema.new_jsi.base_uri)
        assert_equal(nil, schema.new_jsi[{}].jsi_base_uri)
        # passed to JSI instance
        assert_uri('tag:x', schema.new_jsi.merge(base_uri: 'tag:x').base_uri)
        assert_uri('tag:x', schema.new_jsi.merge(base_uri: 'tag:x')[{}].jsi_base_uri)
      end

      it("register") do
        conf = schema.new_jsi(root_uri: 'tag:x')
        # default value
        assert_equal(false, conf.register)
        # does not register by default
        jsi = conf[{}]
        assert_raises(JSI::ResolutionError) { JSI.registry.find('tag:x') }
        # does register
        jsi = conf.merge(register: true)[{}]
        assert_equal(jsi, JSI.registry.find('tag:x'))
      end

      it("stringify_symbol_keys") do
        # default value
        assert_equal(false, schema.new_jsi.stringify_symbol_keys)
        # does not stringify_symbol_keys by default
        assert_equal([:a], schema.new_jsi[{a: {}}].keys)
        # does stringify_symbol_keys
        assert_equal(['a'], schema.new_jsi.merge(stringify_symbol_keys: true)[{a: {}}].keys)
      end

      it("mutable") do
        # default value
        assert_equal(false, schema.new_jsi.mutable)
        # is not mutable by default
        jsi = schema.new_jsi[{}]
        assert_raises(JSI::FrozenError) { jsi['a'] = {} }
        # is mutable
        jsi = schema.new_jsi.merge(mutable: true)[{}]
        jsi['a'] = {}
        assert_equal(schema.new_jsi[{'a' => {}}], jsi)
      end
    end
  end
end

$test_report_file_loaded[__FILE__]
