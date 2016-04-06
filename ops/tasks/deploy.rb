require 'platform_ops/ami_deploy'
require 'platform_ops/ami_finder'
require_relative 'utils'

namespace :deploy do

  desc 'Deploy an AMI'
  task :create, [:source_revision, :environment] do |_t, args|
    args_hash = args.to_h

    ami_id = find_ami(args_hash)
    deployer(args_hash.merge(ami: ami_id)).deploy
  end

  desc 'Delete a deployment'
  task :destroy, [:ami, :source_revision, :environment] do |_t, args|
    deployer(args.to_h).delete
  end

  def find_ami(args)
    config = load_config(__FILE__)[:finder]
    config[:tags][:source_revision] = args[:source_revision]

    image = PlatformOps::AmiFinder.new(config).find_by_tags(config[:tags]).first
    raise "Cannot find image of #{config[:tags]}" unless image

    image_id = image.image_id
    puts "Found #{image.image_id} for #{config[:tags]}"
    image_id
  end

  def deployer(args)
    config = load_config(__FILE__)[args[:environment]].merge(
      ami: args[:ami],
      source_revision: args[:source_revision]
    )
    config[:user_data] = File.read(File.join(File.dirname(__FILE__), config[:user_data]))

    PlatformOps::AmiDeploy.new(config)
  end
end

