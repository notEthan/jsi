require_relative '../test_helper'

require "active_support/core_ext/hash/indifferent_access"

require "hashie"

class IAHash < Hash
  include Hashie::Extensions::MergeInitializer
  include Hashie::Extensions::IndifferentAccess
end

other_instantiations = [
  {name: ActiveSupport::HashWithIndifferentAccess, class: ActiveSupport::HashWithIndifferentAccess},
  {name: 'Hashie with IndifferentAccess', class: IAHash},
]
other_instantiations.each do |inst|
  describe "JSI::Base whose instance is #{inst[:name]}: subscripting with strings and symbols" do
    let(:subject) { schema.new_jsi(instance, to_immutable: nil) }
    let(:schema) { JSI::SimpleWrap }
    let(:instance) do
      instance = inst[:class].new({
        :a => 'alfa',
        'b' => 'brossard',
        :c => {
          :e => 'entomer',
          'f' => [
            {
              'g' => 'gangsta',
            },
          ],
          :h => [],
        },
      })
      instance[:c]['h'] << {
        'i' => 'i',
      }
      instance
    end
    it 'is indifferent' do
      assert_equal('alfa', subject[:a])
      assert_equal('alfa', subject['a'])
      assert_equal('brossard', subject['b'])
      assert_equal('brossard', subject[:b])
      assert_equal('entomer', subject[:c][:e])
      assert_equal('entomer', subject['c']['e'])
      assert_equal('gangsta', subject[:c]['f'][0]['g'])
      assert_equal('gangsta', subject['c'][:f][0][:g])
      assert_equal('i', subject[:c][:h][0]['i'])
      assert_equal(nil, subject['c']['h'][0][:i]) # hwia recurses down array containers to reinstantiate contained hashes as hwia on instantiation, not retrieval, so modifying h later results in a plain hash
    end

    it 'merges' do
      merged = subject.merge(:j => [], 'k' => [])
      assert(merged[:j])
      assert(merged['j'])
      assert(merged[:k])
      assert(merged['k'])
    end
  end
end

$test_report_file_loaded[__FILE__]
