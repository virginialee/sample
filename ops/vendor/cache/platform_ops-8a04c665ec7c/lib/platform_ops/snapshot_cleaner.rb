# Cleanup unused snapshots that you own

require 'aws-sdk-core'
require_relative 'logging'
require_relative 'utils'

module PlatformOps
  class SnapshotCleaner
    include PlatformOps::Logging

    def initialize(config)
      @config = config
      client_options = PlatformOps::Utils.aws_client_options(@config)
      @ec2 = Aws::EC2::Client.new(client_options)
    end

    def clean_unused_snapshots
      # get all completed snapshots
      snapshots = @ec2.describe_snapshots(owner_ids: ['self']).map do |response|
        response.snapshots.select do |s|
          s.state == 'completed'
        end
      end.flatten(1)

      # get all AMIs
      images = @ec2.describe_images(owners: ['self']).map do |response|
        response.images
      end.flatten(1)

      # get snapshot_ids associated with AMIs
      used_snapshot_ids = images.map do |i|
        i.block_device_mappings.select do |m|
          m.ebs && m.ebs.snapshot_id
        end.map do |m|
          m.ebs.snapshot_id
        end
      end.flatten(1)

      # filter snapshots not associated with AMIs
      unused_snapshots = snapshots.select do |s|
        !used_snapshot_ids.include?(s.snapshot_id)
      end

      # map to ids
      unused_snapshot_ids = unused_snapshots.map { |s| s.snapshot_id }

      # clean!
      unused_snapshot_ids.each do |id|
        logger.info "Deleting snapshot: #{id}"
        @ec2.delete_snapshot(snapshot_id: id)
      end

      logger.info "Cleaned #{unused_snapshot_ids.length} unused snapshots"
    end
  end
end
