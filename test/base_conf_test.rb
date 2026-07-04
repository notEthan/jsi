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

    describe("specifying member values") do
      it("from new_jsi kw") do
        # using base_uri and register as representative member values, without and with a default value

        # default base_uri
        assert_equal(nil, schema.new_jsi[{}].jsi_base_uri)
        assert_equal(nil, schema.new_jsi.base_uri)
        # not default base_uri
        assert_uri('tag:x', schema.new_jsi(base_uri: 'tag:x')[{}].jsi_base_uri)
        assert_uri('tag:x', schema.new_jsi(base_uri: 'tag:x').base_uri)

        # default register
        jsi = schema.new_jsi(root_uri: 'tag:x')[{}]
        assert_raises(JSI::ResolutionError) { JSI.registry.find('tag:x') }
        assert_equal(false, schema.new_jsi.register)
        # not default register
        jsi = schema.new_jsi(register: true, root_uri: 'tag:x')[{}]
        assert_equal(jsi, JSI.registry.find('tag:x'))
        assert_equal(true, schema.new_jsi(register: true).register)
      end
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

    describe("behavior according to conf member values") do
      # just the conf that affects instantiation

      it("root_uri + base_uri") do
        # conf.root_uri informs base_uri
        assert_uri('tag:x', schema.new_jsi(root_uri: 'tag:x')[{}].jsi_base_uri)
      end

      it("registry + register") do
        # conf.registry affects registration

        registry = JSI::Registry.new

        # overriding registry does not override default register = false
        jsi = schema.new_jsi(registry: registry, root_uri: 'tag:a')[{}]
        assert_uri('tag:a', jsi.jsi_resource_uri)
        # not registered
        assert_raises(JSI::ResolutionError) { registry.find('tag:a') }
        # nor in the default registry
        assert_raises(JSI::ResolutionError) { JSI.registry.find('tag:a') }

        # override registry with register = true
        jsi = schema.new_jsi(registry: registry, register: true, root_uri: 'tag:b')[{}]
        assert_uri('tag:b', jsi.jsi_resource_uri)
        # registered
        assert_equal(jsi, registry.find('tag:b'))
        # but not in default registry
        assert_raises(JSI::ResolutionError) { JSI.registry.find('tag:b') }

        # with registry: nil
        # does not register (though it wouldn't have done anyway with default register=false)
        jsi = schema.new_jsi(registry: nil, root_uri: 'tag:c')[{}]
        assert_uri('tag:c', jsi.jsi_resource_uri)
        # not registered in the default registry. (local `registry` not passed, no way it could be registered there, but ensure anyway why not)
        assert_raises(JSI::ResolutionError) { JSI.registry.find('tag:c') }
        assert_raises(JSI::ResolutionError) { registry.find('tag:c') }
        # with register=true, still does not register without a registry
        jsi = schema.new_jsi(registry: nil, register: true, root_uri: 'tag:d')[{}]
        assert_uri('tag:d', jsi.jsi_resource_uri)
        # not registered
        assert_raises(JSI::ResolutionError) { JSI.registry.find('tag:d') }
        assert_raises(JSI::ResolutionError) { registry.find('tag:d') }
      end

      it("to_immutable + mutable") do
        # to_immutable ignored if mutable
        # default to_immutable
        c = {}
        jsi = schema.new_jsi(mutable: true)[c]
        assert_same(c, jsi.jsi_node_content)
        assert(!jsi.jsi_node_content.frozen?)
        # to_immutable = nil
        jsi = schema.new_jsi(to_immutable: nil, mutable: true)[c]
        assert_same(c, jsi.jsi_node_content)
        assert(!jsi.jsi_node_content.frozen?)
        # overridden to_immutable
        schema.new_jsi(to_immutable: proc { raise }, mutable: true)[{}]

        # to_immutable: nil + !mutable
        jsi = schema.new_jsi(to_immutable: nil)[c]
        assert_same(c, jsi.jsi_node_content)
        assert(!jsi.jsi_mutable?)
        assert(!jsi.jsi_node_content.frozen?)
        # same as default mutable=false
        jsi = schema.new_jsi(mutable: false, to_immutable: nil)[c]
        assert_same(c, jsi.jsi_node_content)
        assert(!jsi.jsi_mutable?)
        assert(!jsi.jsi_node_content.frozen?)
      end
    end
  end

  describe("Base::Conf::Schema / Schema::MetaSchema#new_schema") do
    it("returns a conf; it instantiates") do
      assert_instance_of(JSI::Base::Conf::Schema, metaschema.new_schema)
      assert_is_a(JSI::Base, metaschema.new_schema[{}])
      assert_is_a(JSI::Schema, metaschema.new_schema[{}])
    end

    describe("behavior according to instantiator member values") do
      it("schema_module_exec") do
        # default value
        assert_equal(nil, metaschema.new_schema.schema_module_exec)
        # passed to jsi_schema_module_exec
        schema = metaschema.new_schema.merge(schema_module_exec: proc { define_method(:x) { :x } })[{}]
        assert_equal(:x, schema.new_jsi({}).x)
      end
    end
  end
end

$test_report_file_loaded[__FILE__]
