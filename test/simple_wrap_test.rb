require_relative 'test_helper'

describe 'JSI::SimpleWrap' do
  let(:subject) { schema.new_jsi(instance) }
  describe 'subscripting with strings and symbols' do
    let(:schema) { JSI::SimpleWrap.schema }
    let(:instance) do
      {
        'b' => 'brossard',
        :c => {
          'f' => [
            {
              'g' => 'gangsta',
            },
          ],
        },
      }
    end

    it 'wraps' do
      assert_equal(Set[schema], subject.jsi_schemas)
      assert(subject.jsi_valid?)
      assert_equal(Set[schema], subject['b', as_jsi: true].jsi_schemas)
      assert_equal(Set[schema], subject[:c].jsi_schemas)
      assert_equal(Set[schema], subject[:c]['f'].jsi_schemas)
      assert_equal(Set[schema], subject[:c]['f'][0].jsi_schemas)
      assert_equal(Set[schema], subject[:c]['f'][0]['g', as_jsi: true].jsi_schemas)
      assert(subject[:c]['f'][0]['g', as_jsi: true].jsi_valid?)
    end
  end
end
