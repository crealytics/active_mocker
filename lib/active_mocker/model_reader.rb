module ActiveMocker
  # @api private

  class ModelReader

    attr_reader :model_name

    def parse(model_name)
      @model_name = model_name
      return ParsedProperties.new(klass, parent_class, model_name) if klass
      false
    end

    def klass
      @klass ||= eval_file(sandbox_model, file_path)
    end

    def sandbox_model
      source = RubyParse.new(read_file)
      has_no_parent_class!(source)
      get_non_active_record_parent_class(source)
      source.modify_parent_class('ActiveMocker::ActiveRecord::Base')
    end

    def get_non_active_record_parent_class(source)
      @parent_class = source.parent_class_name unless Config.model_base_classes.include?(source.parent_class_name)
    end

    def has_no_parent_class!(source)
      raise ModelLoadError::HasNoParentClass.new("#{model_name}") unless source.has_parent_class?
    end

    def module_namespace
      @module ||= Module.new
    end

    def eval_file(string, file_path)
      failure = false
      begin
        module_namespace.module_eval(string, file_path)
        _klass = module_namespace.const_get(module_namespace.constants.last)
      rescue SyntaxError => e
        log_loading_error(e, true)
        failure = true
      rescue Exception => e
        log_loading_error(e, false)
        failure = true
      end
      return false if failure
      _klass
    end

    def log_loading_error(msg, print_to_stdout=false)
      main = "Error loading Model: #{model_name} \n\t#{msg}\n"
      file = "\t#{file_path}\n"
      stack_trace = msg.backtrace_locations.map{|e| "\t#{e}"}.join("\n")
      str = main + file + stack_trace
      Config.logger.error str
      print str if print_to_stdout
    end

    def parent_class
      @parent_class
    end

    def read_file(m_name=model_name)
      Config.file_reader.read(file_path(m_name))
    end

    def file_path(m_name=model_name)
      "#{Config.model_dir}/#{m_name}.rb"
    end

    class ParsedProperties

      attr_reader :klass, :parent_class, :model_name

      def initialize(klass, parent_class, model_name)
        @klass        = klass
        @parent_class = parent_class
        @model_name   = model_name
      end

      def rails_version
        begin
          @rails_version ||= model_name.classify.constantize
        rescue
          raise ModelLoadError::LoadingModelInRails.new($!, model_name)
        end
      end

      def abstract_class
        rails_version.try(:abstract_class)
      end

      def select_only_current_class(type)
        rails_version.reflect_on_all_associations(type).select do |a|
          klass.relationships.send(type).map(&:name).include?(a.name)
        end
      end

      def belongs_to
        select_only_current_class(:belongs_to)
      end

      def has_one
        select_only_current_class(:has_one)
      end

      def has_and_belongs_to_many
        select_only_current_class(:has_and_belongs_to_many)
      end

      def has_many
        select_only_current_class(:has_many)
      end

      def table_name
        return rails_version.try(:table_name) if rails_version.try(:superclass).try(:name) == 'ActiveRecord::Base'
        return nil if rails_version.superclass.try(:table_name) == rails_version.try(:table_name)
        rails_version.try(:table_name)
      end

      def primary_key
        rails_version.primary_key
      end

      def class_methods
        klass.methods(false)
      end

      def scopes
        klass.get_named_scopes
      end

      def scopes_with_arguments
        scopes.map do |name, proc|
          {name => proc.parameters, :proc => proc}
        end
      end

      def class_methods_with_arguments
        class_methods.map do |m|
          {m => klass.method(m).parameters}
        end
      end

      def instance_methods_with_arguments
        instance_methods.map do |m|
          {m => klass.instance_method(m).parameters}
        end
      end

      def instance_methods
        methods = klass.public_instance_methods(false)
        methods << klass.superclass.public_instance_methods(false) if klass.superclass != ActiveRecord::Base
        methods.flatten
      end

      def constants
        const = {}
        klass.constants.each { |c| const[c] = klass.const_get(c) }
        const = const.reject do |c, v|
          v.class == Module || v.class == Class
        end
        const
      end

      def modules
        {included: process_module_names(klass._included),
         extended: process_module_names(klass._extended)}
      end

      def process_module_names(names)
        names.reject { |m| /#{klass.inspect}/ =~ m.name }.map(&:inspect)
      end

    end

  end

end

# Hack for CarrierWave error - undefined method `validate_integrity'
module ActiveRecord
  class Base
    def self.mount_uploader(*args)
      super unless ActiveMocker::Config.build_in_progress
    end
  end
end