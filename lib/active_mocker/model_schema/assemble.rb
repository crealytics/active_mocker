module ActiveMocker

  module ModelLoadError

    class General < Exception

      def initialize(msg)
        @msg = msg
        super
      end

      def class_name
        @msg
      end

    end

    class HasNoParentClass < General
    end

    class LoadingModelInRails < General

      def initialize(error, class_name)
        @msg = "#{class_name}\n  #{error.message}\n  #{error.backtrace.join("\n  ")}"
        super(@msg)
      end

    end
  end

  class ModelSchema

    class Assemble

      attr_reader :progress

      def initialize(progress: nil)
        @progress    = progress
      end

      def increment_progress
        progress.increment unless progress.nil?
      end

      def tables
        @tables ||= SchemaReader.new.tables
      end

      def get_table(model, model_name)
        if model.parent_class.present?
          model = get_model(model_name)
        end
        selected_table = tables.select{|table| table.name == model.table_name}.first
        if selected_table.nil?
          Logger.info "Table: `#{model.table_name}`, can not be found for model #{model_name.camelize}.\n"
        end
        selected_table
      end

      def run
        model_schemas = models.map do |model_name|
          begin
            model = get_model(model_name)

            table      = get_table(model, model_name)
            attributes = []
            attributes = build_attributes(table.fields, primary_key(table.fields, model)) unless table.nil?

            increment_progress

            ModelSchema.new(class_name:      -> { model_name.camelize },
                            table_name:      -> { model.try(:table_name) },
                            attributes:      -> { attributes },
                            _methods:        -> { build_methods(model) },
                            relationships:   -> { build_relationships(model) },
                            constants:       -> { model.constants },
                            modules:         -> { model.modules },
                            parent_class:    -> { model.parent_class },
                            abstract_class:  -> { model.abstract_class}
            )
          rescue Exception => e
            e
          end
        end
        ModelSchemaCollection.new(model_schemas.compact)
      end

      def build_attributes(attributes, primary_attribute)
        attributes.map do |attr|
          attribute = ModelSchema::Attributes
                        .new(name:          attr.name,
                             type:          attr.type,
                             precision:     attr.precision,
                             scale:         attr.scale,
                             default_value: attr.default)
          if primary_attribute == attr
            attribute.primary_key = true
          end
          attribute
        end
      end

      def build_methods(model)
        result = []
        {scope: model.scopes_with_arguments,
         instance: model.instance_methods_with_arguments,
         class: model.class_methods_with_arguments}.each do |type,methods|
          methods.map do |method|
            method_name = method.keys.first.to_s
            arguments   = method.values.first

            result.push(ModelSchema::Methods.new(name:      method_name,
                                                 arguments: arguments,
                                                 type:      type,
                                                 proc:      method[:proc]))
          end
        end
        result
      end

      def build_relationships(model)
        relations_by_type(model).map do |type, relations|
          relations.map do |relation|
            Relationships.new(name:        relation.name,
                              class_name:  relation.class_name,
                              type:        type,
                              through:     nil,
                              source:      nil,
                              foreign_key: relation.foreign_key,
                              join_table:  nil)
          end
        end.flatten
      end

      def relations_by_type(model)
        {belongs_to: model.belongs_to,
         has_one:    model.has_one,
         has_many:   model.has_many,
         has_and_belongs_to_many: model.has_and_belongs_to_many
        }
      end

      def find_join_table(relation, model)
        return relation.join_table if relation.respond_to?(:join_table) && relation.join_table
        tables.select do |table|
          
          "#{model.table_name}_#{relation.name}" == table.name.to_s || "#{relation.name}_#{model.table_name}" == table.name.to_s
        end.first
      end

      def primary_key(attributes, model)
        result = model_primary_key_attribute(attributes, model)
        return result unless result.nil?

        result = find_primary_key(attributes)
        return result unless result.nil?

        find_id_attribute(attributes)
      end

      private

      def model_primary_key_attribute(attributes, model)
        if model.respond_to?(:primary_key) && model.primary_key
          attributes.select do |attr|
            model.primary_key.to_s == attr.name.to_s
          end.first
        end
      end

      def find_primary_key(attributes)
        attributes.select do |attr|
          attr.try(:primary_key)
        end.first
      end

      def find_id_attribute(attributes)
        attributes.select do |attr|
          attr.name.to_sym == :id
        end.first
      end

      public

      def models
        models = '*'
        models = Config.generate_for_mock.underscore if Config.generate_for_mock
        Dir["#{Config.model_dir}/#{models}.rb"].map do |file|
          Pathname.new(file).basename.to_s.sub('.rb', '')
        end
      end

      def get_model(model_file_name)
        model = ModelReader.new.parse(model_file_name)
        raise ModelLoadError::General.new(model_file_name) unless model
        model
      end

      def get_table_name(model_table_name, model_name)
        return model_name.tableize if model_table_name.nil?
        return model_table_name
      end

      def table_to_model_file(table_name)
        table_name.singularize
      end

      def table_to_class_name(table)
        table.camelize.singularize
      end

      def get_belongs_to(class_name, foreign_key)
        get_table(nil, class_name)
      end

    end

  end

end