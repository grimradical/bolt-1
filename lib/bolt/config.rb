require 'logger'
require 'yaml'

module Bolt
  Config = Struct.new(
    :concurrency,
    :format,
    :log_destination,
    :log_level,
    :modulepath,
    :transport,
    :transports
  ) do

    DEFAULTS = {
      concurrency: 100,
      transport: 'ssh',
      format: 'human',
      log_level: Logger::WARN,
      log_destination: STDERR
    }.freeze

    TRANSPORT_OPTIONS = %i[insecure password run_as sudo sudo_password key tty user connect_timeout].freeze

    TRANSPORT_DEFAULTS = {
      connect_timeout: 10,
      insecure: false,
      tty: false
    }.freeze

    TRANSPORTS = %i[ssh winrm pcp].freeze

    def initialize(**kwargs)
      super()
      DEFAULTS.merge(kwargs).each { |k, v| self[k] = v }

      self[:transports] ||= {}
      TRANSPORTS.each do |transport|
        unless self[:transports][transport]
          self[:transports][transport] = {}
        end
        TRANSPORT_DEFAULTS.each do |k, v|
          unless self[:transports][transport][k]
            self[:transports][transport][k] = v
          end
        end
      end
    end

    def default_path
      path = ['.puppetlabs', 'bolt.yml']
      root_path = '~'
      File.join(root_path, *path)
    end

    def read_config_file(path)
      path_passed = path
      path ||= default_path
      path = File.expand_path(path)
      # safe_load doesn't work with psych in ruby 2.0
      # The user controls the configfile so this isn't a problem
      # rubocop:disable YAMLLoad
      File.open(path, "r:UTF-8") { |f| YAML.load(f.read) }
    rescue Errno::ENOENT
      if path_passed
        raise Bolt::CLIError, "Could not read config file: #{path}"
      end
    # In older releases of psych SyntaxError is not a subclass of Exception
    rescue Psych::SyntaxError
      raise Bolt::CLIError, "Could not parse config file: #{path}"
    rescue Psych::Exception
      raise Bolt::CLIError, "Could not parse config file: #{path}"
    rescue IOError, SystemCallError
      raise Bolt::CLIError, "Could not read config file: #{path}"
    end

    def update_from_file(data)
      if data['modulepath']
        self[:modulepath] = data['modulepath'].split(File::PATH_SEPARATOR)
      end

      if data['concurrency']
        self[:concurrency] = data['concurrency']
      end

      if data['format']
        self[:format] = data['format'] if data['format']
      end

      if data['ssh']
        if data['ssh']['private-key']
          self[:transports][:ssh][:key] = data['ssh']['private-key']
        end
        if data['ssh']['insecure']
          self[:transports][:ssh][:insecure] = data['ssh']['insecure']
        end
        if data['ssh']['connect-timeout']
          self[:transports][:ssh][:connect_timeout] = data['ssh']['connect-timeout']
        end
      end

      if data['winrm']
        if data['winrm']['connect-timeout']
          self[:transports][:winrm][:connect_timeout] = data['winrm']['connect-timeout']
        end
      end
      # if data['pcp']
      # end
      # if data['winrm']
      # end
    end

    def load_file(path)
      data = read_config_file(path)
      update_from_file(data) if data
    end

    def update_from_cli(options)
      %i[concurrency transport format modulepath].each do |key|
        self[key] = options[key] if options[key]
      end

      if options[:debug]
        self[:log_level] = Logger::DEBUG
      elsif options[:verbose]
        self[:log_level] = Logger::INFO
      end

      TRANSPORT_OPTIONS.each do |key|
        # TODO: We should eventually make these transport specific
        TRANSPORTS.each do |transport|
          self[:transports][transport][key] = options[key] if options[key]
        end
      end
    end

    def validate
      TRANSPORTS.each do |transport|
        tconf = self[:transports][transport]
        if tconf[:sudo] && tconf[:sudo] != 'sudo'
          raise Bolt::CLIError, "Only 'sudo' is supported for privilege escalation."
        end
      end

      unless %w[human json].include? self[:format]
        raise Bolt::CLIError, "Unsupported format: '#{self[:format]}'"
      end
    end
  end
end
