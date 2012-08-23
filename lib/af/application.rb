require 'log4r'
require 'log4r/configurator'
require 'log4r/outputter/consoleoutputters'

Log4r::Configurator.custom_levels(:DEBUG, :DEBUG_FINE, :DEBUG_MEDIUM, :DEBUG_GROSS, :INFO, :WARN, :ALARM, :ERROR, :FATAL)

module Af
  class Application < ::Af::CommandLiner
    DEFAULT_LOG_LEVEL = Log4r::ALL

    opt :daemon, "run as daemon", :short => :d
    opt :log_dir, "directory to store log files", :default => "/var/log/af"
    opt :log_file_basename, "base name of file to log output", :default => "af"
    opt :log_file_extension, "extension name of file to log output", :default => '.log'
    opt :log_file, "full path name of log file", :type => :string, :env => "AF_LOG_FILE"
    opt :log_all_output, "start logging output", :default => false
    opt :log_level, "set the levels of one or more loggers", :type => :string, :env => "AF_LOG_LEVEL"

    attr_accessor :has_errors, :daemon, :log_dir, :log_file, :log_file_basebane, :log_file_extension, :log_all_output, :log_level

    @@singleton = nil

    def self.singleton(safe = false)
      if @@singleton.nil?
        if safe
          @@singleton = new
        else
          fail("Application @@singleton not initialized! Maybe you are using a Proxy before creating an instance? or use SafeProxy")
        end
      end
      return @@singleton
    end

    def initialize
      super
      @@singleton = self
      @loggers = {}
      @logger_levels = {:default => DEFAULT_LOG_LEVEL}
      @log4r_formatter = nil
      @log4r_outputter = {}
      @log4r_name_suffix = ""
      ActiveRecord::ConnectionAdapters::ConnectionPool.initialize_connection_application_name(self.class.database_application_name)
      $stdout.sync = true
      $stderr.sync = true
      update_opts :log_file_basename, :default => name
    end

    def self.database_application_name
      return "#{self.name}(pid: #{Process.pid})"
    end

    def name
      return self.class.name
    end

    def log4r_name_suffix
      return @log4r_name_suffix
    end

    def set_new_log4r_name_suffix(new_log4r_name_suffix)
      @log4r_name_suffix = new_log4r_name_suffix
      log4r_outputter.formatter = log4r_formatter
      return @log4r_name_suffix
    end

    def log4r_pattern_formatter_format
      return "%l %C#{log4r_name_suffix} %M"
    end

    def log4r_pattern_formatter_external_format
      return "%l #{name}::%C#{log4r_name_suffix} %M"
    end

    def log4r_formatter(logger_name = :default)
      logger_name = :default if logger_name == name
      if logger_name == :default
        return Log4r::PatternFormatter.new(:pattern => log4r_pattern_formatter_format)
      else
        return Log4r::PatternFormatter.new(:pattern => log4r_pattern_formatter_external_format)
      end
    end

    def log4r_outputter(logger_name = :default)
      logger_name = :default if logger_name == name
      unless @log4r_outputter.has_key?(logger_name)
        @log4r_outputter[logger_name] = Log4r::StdoutOutputter.new("stdout", :formatter => log4r_formatter(logger_name))
      end
      return @log4r_outputter[logger_name]
    end

    def logger_level(logger_name = :default)
      logger_name = :default if logger_name == name
      return @logger_levels[logger_name] || DEFAULT_LOG_LEVEL
    end

    def set_logger_level(new_logger_level, logger_name = :default)
      logger_name = :default if logger_name == name
      @logger_level[logger_name] = new_logger_level
    end

    def logger(logger_name = :default)
      logger_name = :default if logger_name == name
      unless @loggers.has_key?(logger_name)
        l = Log4r::Logger.new(logger_name == :default ? name : logger_name)
        l.outputters = log4r_outputter(logger_name)
        l.level = logger_level(logger_name)
        @loggers[logger_name] = l
      end
      return @loggers[logger_name]
    end

    def self.run(*arguments)
      # this ARGV hack is here for test specs to add script arguments
      ARGV[0..-1] = arguments if arguments.length > 0
      self.new.run
    end

    def run(usage = nil, options = {})
      @options = options
      @usage = (usage or "#{self.class.name} [OPTIONS]")

      command_line_options(@options, @usage)

      post_command_line_parsing

      pre_work

      work

      exit @has_errors ? 1 : 0
    end

    protected
    def option_handler(option, argument)
    end

    # Overload to do any operations that need to be handled before work is called.
    # call exit if needed.  always call super
    def pre_work
      logger.debug_gross "pre work"
    end

    def post_command_line_parsing
      if @log_level.present?
        begin
          mergeables = JSON.parse(@log_level)
        rescue StandardError => e
          logger.error "log_level JSON parsing failure: #{e.message}, log_level: #{@log_level}"
          mergables = {}
        end
        @logger_levels.merge!(mergables)
        @logger_levels.each do |logger_name, logger_level|
          logger_name = :default if logger_name == "default"
          l = loggers[logger_name]
          if l.presnet?
            begin
              logger_level_value = logger_level.constantize
            rescue StandardError => e
              logger.error "invalid log level value: #{logger_level} for logger: #{logger_name}"
              logger_level_value = DEFAULT_LOG_LEVEL
            end
            l.level = logger_level_value
          end
        end
      end

      if @daemon
        @log_all_output = true
      end

      if @log_all_output
        path = Pathname.new(@log_dir.to_s)
        path.mkpath
        if @log_file.present?
          log_path =  @log_file
        else
          log_path =  path + "#{@log_file_basename}#{@log_file_extension}"
        end
        $stdout.reopen(log_path, "a")
        $stderr.reopen(log_path, "a")
        $stdout.sync = true
        $stderr.sync = true
      end

      if @daemon
        logger.info "Daemonizing"
        pid = fork
        if pid
          exit 0
        else
          logger.info "forked"
          Process.setsid
          trap 'SIGHUP', 'IGNORE'
          cleanup_after_fork
        end
      end
    end

    def cleanup_after_fork
      ActiveRecord::Base.connection.reconnect!
    end

    module Proxy
      def logger(logger_name = (self.try(:name) || "Unknown"))
        return ::Af::Application.singleton.logger(logger_name)
      end

      def name
        return ::Af::Application.singleton.name
      end
    end

    module SafeProxy
      def logger(logger_name = (self.try(:name) || "Unknown"))
        return ::Af::Application.singleton(true).logger(logger_name)
      end

      def name
        return ::Af::Application.singleton(true).name
      end
    end
  end
end
