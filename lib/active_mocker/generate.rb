require 'ruby-progressbar'
require 'forwardable'
module ActiveMocker
class Generate
  extend Forwardable

  attr_reader :silence

  def initialize(silence: false)
    @silence = silence
    Config.clear_log
    Config.build_in_progress = true
    create_template
    Config.build_in_progress = false
  end

  private

  def generate_model_schema
    ActiveMocker::ModelSchema::Assemble.new(progress: progress).run
  end

  def model_count
    @model_count ||= ActiveMocker::ModelSchema::Assemble.new.models.count
  end

  def progress
    return @progress if !@progress.nil? || silence == true
    progress_options = {:title => 'Generating Mocks',
                        :total => model_count * 2,
                        format: '%t |%b>>%i| %p%%'}
    @progress = ProgressBar.create(progress_options)
  end

  def increment_progress
    progress.increment unless silence
  end

  attr_accessor :mocks_created, :not_valid_models
  def create_template
    @mocks_created    = 0
    @not_valid_models = 0
    clean_up
    generate_model_schema.each do |model|
      next unless generate_and_rescue(model)
    end
    exit_message
  end

  def generate_and_rescue(model)
    begin
      raise_if_is_exception!(model)
      generate_mock(model)
      increase_mocks_created
    rescue Exception => exception
      log_failed_mock(exception, model)
      false
    end
  end

  def increase_mocks_created
    @mocks_created += 1
    increment_progress
  end

  def raise_if_is_exception!(model)
    raise model if model.class.ancestors.include?(Exception)
  end

  def exit_message
    progress.finish unless silence
    Config.logger.info "Generated #{mocks_created} of #{model_count} mocks."
    failed_mocks = (model_count - not_valid_models) - mocks_created
    if failed_mocks > 0
      puts "#{failed_mocks} mock(s) out of #{model_count} failed. See `log/active_mocker.log` for more info."
    end
  end

  def generate_mock(model)
    klass_str = generate_mock_string(model)
    save_mock_file(klass_str, model)
    log_save(model)
  end

  def log_failed_mock(exception, model)
    Config.logger.debug $!.backtrace
    Config.logger.debug exception
    Config.logger.info "Failed to load #{model.class_name} model."
  end

  def log_save(model)
    Config.logger.info "saving mock #{model.class_name} to #{Config.mock_dir}"
  end

  def save_mock_file(klass_str, model)
    File.open(File.join(Config.mock_dir, "#{model.class_name.tableize.singularize}_mock.rb"), 'w').write(klass_str)
  end

  def generate_mock_string(model)
    model.render(File.open(File.join(File.expand_path('../', __FILE__), 'mock_template.erb')).read, mock_append_name)
  end

  def clean_up
    raise "Config.mock_dir is not a subdirectory of the current directory, aborting!" unless in_current_directory?(Config.mock_dir) || ENV["GENERATE_ELSEWHERE"]
    FileUtils.rm_rf("#{Config.mock_dir}/", secure: true) unless Config.generate_for_mock
    FileUtils::mkdir_p Config.mock_dir unless File.directory? Config.mock_dir
  end

  def in_current_directory?(dir)
    dir && File.expand_path(dir).include?(File.expand_path(Dir.getwd))
  end

  def mock_append_name
    'Mock'
  end

end
end


