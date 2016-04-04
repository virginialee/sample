require 'platform_ops/ami_builder'
require 'platform_ops/ami_finder'
require 'platform_ops/ssh_connection'
require 'platform_ops/chef_cookbooks_vendorer'
require 'platform_ops/chef_secret'
require 'chef_runner'
require_relative 'utils'

namespace :ami do

  desc 'Build an app AMI'
  task :app, [:source_revision] do |_t, args|
    config = load_config(__FILE__)
    config['ami']['app'][:image_tags][:source_revision] = args[:source_revision]

    # find the latest app base AMI
    image_tags = config['ami']['app'][:tags]
    ami_params = config['ami']['app'][:tags].merge({ region: config['ami']['app'][:region] })
    images = PlatformOps::AmiFinder.new(ami_params).find_by_tags(image_tags)
    raise "Cannot find image of #{image_tags}" unless images.size > 0
    app_base_ami = images.max_by { |image| Date.parse(image.creation_date) }.image_id
    p "Found the latest image #{app_base_ami} for #{image_tags}"
    config['ami']['app'][:source_ami] = app_base_ami

    build_app_ami(config)
  end

  desc 'Build a build agent docker AMI'
  task :build_agent_docker do
    build_ami('build_agent_docker')
  end

  def build_ami(name, source_revision=nil)
    config_all = load_config(__FILE__)

    config_ami = config_all['ami'][name]
    config_ami[:image_tags][:source_revision] = source_revision if source_revision

    config_provision = config_all['provision'][name]

    image_id = nil

    PlatformOps::ChefSecret.new(config_all['provision']['chef_secret']).with_secret_file do |secret_file_path|

      config_provision['chef_runner'][:chef_repo][:secret] = secret_file_path

      image_id = PlatformOps::AmiBuilder.new(config_ami).build do |instance|

        config_provision['chef_runner'][:servers].map! do |server|
          server[:host] = instance.public_ip_address
          server
        end

        PlatformOps::ChefCookbooksVendorer.new('./chef_repo', 'cookbooks').vendor_chef_repo

        SSHKit.config.format = :pretty
        ChefRunner.bootstrap(config_provision['chef_runner'])
        ChefRunner.zero(config_provision['chef_runner'])

        yield config_provision, instance.public_ip_address if block_given?

      end
      puts "Finished building new AMI #{image_id}"
    end

    image_id
  end

  def build_app_ami(config)
    config_provision = config['provision']['app']
    image_id = nil

    PlatformOps::ChefSecret.new(config['provision']['chef_secret']).with_secret_file do |secret_file_path|

      config_provision['chef_runner'][:chef_repo][:secret] = secret_file_path

      image_id = PlatformOps::AmiBuilder.new(config['ami']['app']).build do |instance|

        config_provision['chef_runner'][:servers].map! do |server|
          server[:host] = instance.public_ip_address
          server
        end

        PlatformOps::ChefCookbooksVendorer.new('./chef_repo', 'cookbooks').vendor_chef_repo

        SSHKit.config.format = :pretty
        ChefRunner.bootstrap(config_provision['chef_runner'])
        ChefRunner.zero(config_provision['chef_runner'])

        Dir.chdir config_provision['scp'][:dir] do
          config_provision['ssh'][:host] = instance.public_ip_address
          source = config_provision['scp'][:source]
          target = config_provision['scp'][:target]
          target_name = File.basename(target, File.extname(target))

          # copy app src into app ami
          ssh = PlatformOps::SshConnection.new(config_provision['ssh'])
          ssh.session do |session|
            session.scp.upload! source, target
            puts session.exec!("unzip #{target} -d ~")
            puts session.exec!("rm #{target}")
            puts session.exec!("mv ~/#{target_name} ~/dist")
          end

          puts 'Dist uploaded'
        end

      end
      puts "Finished building new AMI #{image_id}"

    end
    image_id
  end

end
