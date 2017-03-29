require 'scorpio'
require 'pickle'

module Scorpio
  class Model
    module PickleAdapter
      include ::Pickle::Adapter::Base

      # Gets a list of the available models for this adapter
      #
      # all of the Scorpio models MUST be loaded before this gets called.
      def self.model_classes
        ObjectSpace.each_object(Class).select { |klass| klass < ::Scorpio::Model }
      end

      # get a list of column names for a given class
      def self.column_names(klass)
        klass.all_schema_properties
      end

      # Get an instance by id of the model
      def self.get_model(klass, id)
        if klass.respond_to?(:read)
          klass.read(id: id)
        elsif klass.respond_to?(:index)
          return klass.index.detect { |record| record.id == id }
        else
          raise
        end
      end

      # Find the first instance matching conditions
      def self.find_first_model(klass, conditions)
        # TODO don't load all
        find_all_models(klass, conditions).first
      end

      # Find all models matching conditions
      def self.find_all_models(klass, conditions)
        klass.index.select do |record|
          (conditions || {}).all? do |attr, value|
            record.public_send(attr) == value
          end
        end
      end

      # Create a model using attributes
      def self.create_model(klass, attributes)
        klass.new(attributes).post
      end
    end
  end
end
