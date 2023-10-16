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
      assert_schemas([schema], subject.jsi_descendent_node(['b']))
      assert_schemas([schema], subject.jsi_descendent_node([:c]))
      assert_schemas([schema], subject.jsi_descendent_node([:c, 'f']))
      assert_schemas([schema], subject.jsi_descendent_node([:c, 'f', 0]))
      assert_schemas([schema], subject.jsi_descendent_node([:c, 'f', 0, 'g']))
      assert(subject.jsi_descendent_node([:c, 'f', 0, 'g']).jsi_valid?)
    end
  end
end

$test_report_file_loaded[__FILE__]
