require 'aws-sdk-core'
require 'chef/encrypted_data_bag_item'
require 'json'
require_relative 'utils'

module PlatformOps
  class ChefSecret

    def initialize(config)
      config = PlatformOps::Utils.validated_config config, %i(bucket_name bucket_key)

      @bucket = config[:bucket_name]
      @bucket_key = config[:bucket_key]
      @data_bag_path = config[:data_bag_path]

      # backward compatible with :bucket_region
      config[:region] = config[:bucket_region] if config[:bucket_region]

      client_options = PlatformOps::Utils.aws_client_options(config)

      @s3_client = Aws::S3::Client.new(client_options)
      @secret = get_secret
    end

    def data_bag_item(data_bag_name, item_name)
      bag_file = File.join(@data_bag_path, data_bag_name, "#{item_name}.json")
      bag_data = JSON.parse(File.read(bag_file))
      Chef::EncryptedDataBagItem.new(bag_data, @secret)
    end

    def with_secret_file
      Dir.mktmpdir do |dir|
        secret_file_path = File.join(dir, @bucket_key)
        File.write(secret_file_path, @secret)
        yield secret_file_path if block_given?
      end
    end

    private

    def get_secret
      @s3_client.get_object(bucket: @bucket, key: @bucket_key).body.read.strip
    end
  end
end
