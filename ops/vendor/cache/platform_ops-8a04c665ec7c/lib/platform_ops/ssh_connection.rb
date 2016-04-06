require 'net/ssh'
require 'net/scp'
require 'retryable'
require_relative 'logging'
require_relative 'utils'

module PlatformOps
  class SshConnection
    include PlatformOps::Logging

    def initialize(config)
      @config = PlatformOps::Utils.validated_config config, %i(host user)
    end

    def poll_ssh
      Retryable.retryable(tries: 24, sleep: 5, :on => [Net::SSH::ConnectionTimeout, Timeout::Error, Errno::ETIMEDOUT, Errno::EHOSTUNREACH, Errno::EHOSTDOWN, Errno::ECONNABORTED, Errno::ECONNREFUSED]) do |retries, exception|
        logger.info "Attempt ##{retries} failed with exception: #{exception}" if retries > 0

        session do |ssh|
          ssh.exec!('true')
        end
      end
    end

    def session(&block)
      opt = {}

      opt[:password] = @config[:ssh_password] if @config[:ssh_password]
      opt[:keys] = @config[:key_files].map(&File.method(:expand_path)) if @config[:key_files]

      auth_methods = []
      auth_methods << 'publickey' if @config[:key_files]
      auth_methods << 'password' if @config[:ssh_password]
      opt[:auth_methods] = auth_methods

      opt[:paranoid] = false
      opt[:user_known_hosts_file] = '/dev/null'
      opt[:config] = false # do not load your ~/.ssh/config
      opt[:timeout] = @config[:timeout] if @config[:timeout]

      Net::SSH.start(@config[:host], @config[:user], opt, &block)
    end

  end
end
