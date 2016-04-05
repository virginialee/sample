require 'aws-sdk-core'
require 'erb'
require 'securerandom'

module PlatformOps
  class Utils

    def self.aws_client_options(config)
      allowed_keys = [:region, :retry_limit]
      options = config.select { |k,v| allowed_keys.include? k }
      defaults = { retry_limit: 5 }
      options = defaults.merge(options)

      if config[:assume_role_credentials]
        options[:credentials] = create_assume_role_credentials(config[:assume_role_credentials])
      end

      options
    end

    def self.validated_config(config, required_keys)
      required_keys.each do |key|
        raise "#{key} is not provided in the config" unless config.key?(key)
      end
      config
    end

    # shamelessly stolen from aws_helpers
    def self.poll(delay, max_attempts, &block)
      attempts = 0
      while true
        break if block.call(attempts)
        attempts += 1
        raise "Maximum attempts reached but still failed" if attempts == max_attempts
        sleep(delay)
      end
    end

    private

    def self.create_assume_role_credentials(config)
      template = config[:role_session_name] || 'Session<%= random_string %>'
      args = OpenStruct.new(random_string: SecureRandom.hex(4))
      session_name = ::ERB.new(template).result(args.instance_eval { binding })
      Aws::AssumeRoleCredentials.new(
        config.merge(
          role_session_name: session_name
        )
      )
    end

  end
end
