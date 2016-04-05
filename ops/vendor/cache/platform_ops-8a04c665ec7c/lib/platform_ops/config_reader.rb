module PlatformOps
  class ConfigReader

    # @param config_folder_path [String] absolute path to config folder
    def initialize(config_folder_path)
      @folder_path = config_folder_path
    end

    # Checks if a given config file exists
    # @param args [*String] path to the config file relative to the config folder
    # @return [Boolean] true if the config file exists, otherwise false
    def exists(*args)
      raise ArgumentError.new('No arguments passed to ConfigReader#exists') if args.empty?

      config = case
                 when args.last.end_with?('.json')
                   read_json_config(args)
                 when args.last.end_with?('.yaml')
                   read_yaml_config(args)
                 else
                   read_json_config(args) || read_yaml_config(args)
               end

      !config.nil?
    end

    # Returns the contents of the given config file as a hash
    # @param args [*String] path to the config file relative to the config folder
    # @return [Hash] contents of config file
    def read(*args)
      raise ArgumentError.new('No arguments passed to ConfigReader#read') if args.empty?

      config = case
                 when args.last.end_with?('.json')
                   read_json_config(args)
                 when args.last.end_with?('.yaml')
                   read_yaml_config(args)
                 else
                   read_json_config(args) || read_yaml_config(args)
               end

      raise ArgumentError.new("Config file #{File.join(args)} not found") if config.nil?

      config
    end

    private

    def read_json_config(args)
      path = file_path(args, 'json')
      File.exists?(path) ? JSON.parse(IO.read(path), :symbolize_names => true) : nil
    end

    def read_yaml_config(args)
      path = file_path(args, 'yaml')
      File.exists?(path) ? YAML.load_file(path) : nil
    end

    def file_path(args, extension)
      path = args[0..-2]
      path << (args.last.end_with?(extension) ? args.last : "#{args.last}.#{extension}")

      File.join(@folder_path, path)
    end
  end
end
