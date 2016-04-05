require 'aws-sdk-core'
require 'retryable'
require 'aws_helpers/ec2'
require_relative 'logging'
require_relative 'utils'

module PlatformOps
  class AmiCleaner
    include PlatformOps::Logging

    def initialize(config)
      @config = PlatformOps::Utils.validated_config config, %i(region image_name)

      client_options = PlatformOps::Utils.aws_client_options(@config)

      @aws_helpers_ec2 = AwsHelpers::EC2.new(client_options)
    end

    def clean
      @aws_helpers_ec2.images_delete_by_time(@config[:image_name], @config[:time], {max_attempts: @config[:max_attempts]})
    end

  end
end
