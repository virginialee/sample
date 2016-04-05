require 'aws-sdk-core'
require 'securerandom'
require 'retryable'
require 'aws_helpers/ec2'
require 'base64'
require_relative 'ssh_connection'
require_relative 'logging'
require_relative 'utils'
require_relative 'instance_helpers'

module PlatformOps
  class AmiBuilder
    include PlatformOps::Logging

    def initialize(config)
      @config = PlatformOps::Utils.validated_config config, %i(source_ami user image_name)

      client_options = PlatformOps::Utils.aws_client_options(@config)

      @ec2 = Aws::EC2::Client.new(client_options)
      @helper = PlatformOps::InstanceHelpers.new(@ec2)

      @aws_helpers_ec2 = AwsHelpers::EC2.new(client_options)
    end

    def build
      begin
        if @config[:security_group_id]
          security_group_id = @config[:security_group_id]
        else
          security_group_id = create_security_group
          authorize_ssh_to_security_group(security_group_id)
        end

        instance_id = create_instance(security_group_id)

        @helper.poll_instance_running(instance_id)
        instance = @helper.get_instance_by_id(instance_id)
        poll_ssh(instance)

        yield instance

        image_id = @aws_helpers_ec2.image_create(instance_id, @config[:image_name], {
          additional_tags: image_tags_kvs,
          poll_image_available: {
            delay: 15,
            max_attempts: @config[:poll_image_max_attempt] || 40
          }
        })

        add_launch_permission(image_id) if @config[:launch_permission]

        image_id
      ensure
        unless @config[:no_cleanup]
          terminate_instance(instance_id) if instance_id
          delete_security_group(security_group_id) if security_group_id && !@config[:security_group_id]
        end
      end

    end

    private

    def create_security_group
      logger.info 'Creating security group'

      result = @ec2.create_security_group(
        group_name: generate_security_group_name,
        description: "Temporary security group for building AMI"
      )
      security_group_id = result.group_id
      logger.info "Created security group #{security_group_id}"
      security_group_id
    end

    def authorize_ssh_to_security_group(security_group_id)
      logger.info "Authorising security group #{security_group_id}"

      Retryable.retryable(tries: 5, sleep: 5, :on => Aws::EC2::Errors::ServiceError) do |retries, exception|
        logger.info "Attempt ##{retries} failed with exception: #{exception}" if retries > 0
        @ec2.authorize_security_group_ingress(
          group_id: security_group_id,
          ip_protocol: 'tcp',
          from_port: 22,
          to_port: 22,
          cidr_ip: '0.0.0.0/0'
        )
      end

      logger.info "Authorised security group #{security_group_id}"
    end

    def create_instance(security_group_id)
      settings = {
        image_id: @config[:source_ami],
        min_count: 1,
        max_count: 1,
        security_group_ids: [security_group_id],
        instance_type: @config[:instance_type] || 'c4.large',
        monitoring: {
          enabled: true
        }
      }

      settings[:subnet_id] = @config[:subnet_id] if @config[:subnet_id]

      if @config[:keypair_name]
        settings[:key_name] = @config[:keypair_name]
      else
        settings[:user_data] = user_data
      end

      if @config[:volume_size]
        settings[:block_device_mappings] = [{
          device_name: '/dev/sda1',
          ebs: {
            volume_size: @config[:volume_size],
            delete_on_termination: true,
            volume_type: 'gp2'
          }
        }]
      end

      if @config[:iam_instance_profile]
        settings[:iam_instance_profile] = @config[:iam_instance_profile]
      end

      logger.info "Creating instance from image #{settings[:image_id]}"
      result = @ec2.run_instances(settings)
      instance_id = result.instances[0].instance_id
      logger.info "Created instance #{instance_id}"
      instance_id
    end

    def poll_ssh(instance)
      logger.info "Polling SSH on instance #{instance.instance_id}"

      ssh_config = {
        host: instance.public_ip_address,
        user: @config[:user],
        timeout: 30,
        key_files: @config[:key_files] || ['~/.ssh/id_rsa']
      }

      PlatformOps::SshConnection.new(ssh_config).poll_ssh

      logger.info "Instance #{instance.instance_id} can be connected via SSH on #{instance.public_ip_address} or #{instance.public_dns_name}"
    end

    def terminate_instance(instance_id)
      @ec2.terminate_instances(instance_ids: [instance_id])
      @ec2.wait_until(:instance_terminated, instance_ids: [instance_id]) { |waiter|
        waiter.before_wait { |attempts|
          logger.info "Terminating instance #{instance_id}... Waiting #{attempts * waiter.interval} seconds"
        }
      }
      logger.info "Terminated instance #{instance_id}"
    end

    def delete_security_group(security_group_id)
      logger.info 'Deleting security group'

      Retryable.retryable(tries: 5, sleep: 5, :on => Aws::EC2::Errors::ServiceError) do |retries, exception|
        logger.info "Attempt ##{retries} failed with exception: #{exception}" if retries > 0
        @ec2.delete_security_group(
          group_id: security_group_id
        )
      end

      logger.info "Deleted security group #{security_group_id}"
    end

    def image_tags_kvs
      defaults = {
        'Base_Image_Id': @config[:source_ami]
      }
      tags = defaults.merge(@config[:image_tags] || {})
      tags.map { |k, v| { key: k.to_s, value: v } }
    end

    def generate_security_group_name
      loop do
        group_name = "AmiBuilder #{SecureRandom.hex(6)}"
        existing_security_groups = @ec2.describe_security_groups(
          filters: [
            { name: 'group-name', values: [group_name] }
          ]
        ).security_groups

        return group_name if existing_security_groups.length == 0

        logger.info "Security group name #{group_name} already exists. Try another one."
      end
    end

    def user_data
      key = IO.read(File.expand_path('~/.ssh/id_rsa.pub')).strip

      args = OpenStruct.new(public_key: key)

      template = <<EOF
#cloud-config
ssh_authorized_keys:
  - "<%= public_key %>"
EOF

      data_str = ERB.new(template).result(args.instance_eval { binding })

      Base64.encode64(data_str)
    end

    def add_launch_permission(image_id)
      @ec2.modify_image_attribute(
        image_id: image_id,
        launch_permission: {
          add: @config[:launch_permission]
        }
      )
      logger.info "Shared AMI #{image_id} with accounts: #{@config[:launch_permission]}"
    end
  end
end
