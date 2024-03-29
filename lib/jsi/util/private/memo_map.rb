# frozen_string_literal: true

module JSI
  module Util::Private
    class MemoMap
      def initialize(key_by: nil, &block)
        @key_by = key_by
        @block = block || raise(ArgumentError, "no block given")

        # each result has its own mutex to update its memoized value thread-safely
        @result_mutexes = {}
        # another mutex to thread-safely initialize each result mutex
        @result_mutexes_mutex = Mutex.new

        @results = {}
      end

      def key_for(inputs)
        if @key_by
          @key_by.call(**inputs)
        else
          inputs
        end
      end
    end

    class MemoMap::Mutable < MemoMap
      Result = AttrStruct[*%w(
        value
        inputs
        inputs_hash
      )]

      class Result
      end

      def [](**inputs)
        key = key_for(inputs)

        result_mutex = @result_mutexes_mutex.synchronize do
          @result_mutexes[key] ||= Mutex.new
        end

        result_mutex.synchronize do
          inputs_hash = inputs.hash
          if @results.key?(key) && inputs_hash == @results[key].inputs_hash && inputs == @results[key].inputs
            @results[key].value
          else
            value = @block.call(**inputs)
            @results[key] = Result.new(value: value, inputs: inputs, inputs_hash: inputs_hash)
            value
          end
        end
      end
    end

    class MemoMap::Immutable < MemoMap
      def [](**inputs)
        key = key_for(inputs)

        result_mutex = @result_mutexes_mutex.synchronize do
          @result_mutexes[key] ||= Mutex.new
        end

        result_mutex.synchronize do
          if @results.key?(key)
            @results[key]
          else
            @results[key] = @block.call(**inputs)
          end
        end
      end
    end
  end
end
