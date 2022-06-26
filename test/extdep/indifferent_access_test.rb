require_relative '../test_helper'

require "active_support/core_ext/hash/indifferent_access"

describe 'JSI::Base whose instance is ActiveSupport::HashWithIndifferentAccess' do
  let(:subject) { schema.new_jsi(instance) }
  describe 'subscripting with strings and symbols' do
    let(:schema) { JSI::SimpleWrap }
    let(:instance) do
      instance = ActiveSupport::HashWithIndifferentAccess.new({
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
  end
end
