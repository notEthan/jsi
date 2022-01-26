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
      assert_schemas([schema], subject)
      assert(subject.jsi_valid?)
      assert_schemas([schema], subject['b', as_jsi: true])
      assert_schemas([schema], subject[:c])
      assert_schemas([schema], subject[:c]['f'])
      assert_schemas([schema], subject[:c]['f'][0])
      assert_schemas([schema], subject[:c]['f'][0]['g', as_jsi: true])
      assert(subject[:c]['f'][0]['g', as_jsi: true].jsi_valid?)
    end
  end
end
