require_relative 'logging'

module PlatformOps
  module ShellHelpers

    include PlatformOps::Logging

    def execute(cmd, options = {})
      options[:dir] ||= Dir.pwd
      options[:quiet] ||= false
      options[:args] ||= []
      options[:fail_hard] ||= false

      logger.info "#{cmd}\n" unless options[:quiet]

      success = nil
      exit_code = nil

      Dir.chdir(options[:dir]) do
        success = Kernel.system(cmd, *options[:args])
        exit_code = $?.exitstatus

        exit exit_code if options[:fail_hard] && !success
      end

      OpenStruct.new(ok?: success, code: exit_code)
    end

    def self.execute(cmd, options = {})
      options[:dir] ||= Dir.pwd
      options[:quiet] ||= false
      options[:args] ||= []
      options[:fail_hard] ||= false

      logger.info "#{cmd}\n" unless options[:quiet]

      success = nil
      exit_code = nil

      Dir.chdir(options[:dir]) do
        success = Kernel.system(cmd, *options[:args])
        exit_code = $?.exitstatus

        exit exit_code if options[:fail_hard] && !success
      end

      OpenStruct.new(ok?: success, code: exit_code)
    end
  end
end
