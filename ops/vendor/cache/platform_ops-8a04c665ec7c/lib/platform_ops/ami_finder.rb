require 'aws-sdk-core'
require_relative 'logging'
require_relative 'utils'

module PlatformOps
  class AmiFinder
    include PlatformOps::Logging

    def initialize(config)
      @config = config

      client_options = PlatformOps::Utils.aws_client_options(@config)

      @ec2 = Aws::EC2::Client.new(client_options)
    end

    def find_by_tags(tags)
      filters = tags.map do |k, v|
        { name: "tag:#{k.to_s}", values: [v] }
      end
      filters << { name: 'state', values: ['available'] }
      @ec2.describe_images(filters: filters).images
    end
  end
end
