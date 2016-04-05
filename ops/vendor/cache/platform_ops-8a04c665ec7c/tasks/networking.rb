require 'aws-sdk-resources'
require_relative '../lib/platform_ops/networking'

namespace :platform_ops do
  namespace :networking do

    desc 'Searches a VPC for an unoccupied CIDR block of a given size'
    task :find_available_cidr, [:vpc_id,:bits] do |_t, args|
      vpc = Aws::EC2::Vpc.new(args[:vpc_id])

      vpc_cidr = vpc.cidr_block
      occupied_subnets = vpc.subnets.to_a.map(&:cidr_block)

      cidr = PlatformOps::Networking.find_unused_cidr_block(vpc_cidr, occupied_subnets, args[:bits].to_i)

      if cidr
        puts "Found CIDR block #{cidr}"
      else
        puts "No available /#{args[:bits]} CIDR block in VPC #{args[:vpc_id]}"
      end
    end
  end
end
