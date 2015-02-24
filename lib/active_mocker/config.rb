module ActiveMocker

  class Config
    class << self

      attr_accessor :schema_file,
                    :model_dir,
                    :mock_dir,
                    :model_base_classes,
                    :file_reader,
                    :build_in_progress,
                    :log_location,
                    :clear_log_on_build,
                    :generate_for_mock

      def model_base_classes=(val)
        @model_base_classes = val
      end

      def set
        load_defaults
        yield self
      end

      def load_defaults
        @schema_file        = nil unless @schema_file
        @model_dir          = nil unless @model_dir
        @mock_dir           = nil unless @mock_dir
        @model_base_classes = %w[ ActiveRecord::Base ] unless @model_base_classes
        @file_reader        = FileReader     unless @file_reader
        @log_location       = 'log/active_mocker.log' unless @log_location
        @clear_log_on_build = true
        @generate_for_mock  = ENV['MODEL']
        setup_defaults(Object.const_defined?('Rails') ? Rails.root : Dir.getwd)
      end

      def logger
        default_logger
      end

      def reset_all
        [ :@schema_file,
          :@model_dir,
          :@mock_dir,
          :@model_base_classes,
          :@file_reader,
          :@logger,
          :@schema_file,
          :@model_dir,
          :@mock_dir].each{|ivar| instance_variable_set(ivar, nil)}
      end

      def default_logger
        FileUtils.mkdir_p(File.dirname(@log_location)) unless File.directory?(File.dirname(@log_location))
        ::Logger.new(@log_location)
      end

      def setup_defaults(base_dir)
        @schema_file = File.join(base_dir, 'db/schema.rb') unless @schema_file
        @model_dir   = File.join(base_dir, 'app/models')   unless @model_dir
        @mock_dir    = File.join(base_dir, 'spec/mocks')   unless @mock_dir
      end

      def clear_log
        if @clear_log_on_build && File.exist?(@log_location)
          FileUtils.rm(@log_location)
        end
      end

    end

  end

end

