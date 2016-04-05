require 'aws-sdk-core'
require 'aws-sdk-resources'
require 'base64'
require 'erb'
require 'netaddr'
require 'securerandom'
require_relative '../utils'
require_relative '../logging'
require_relative '../instance_helpers'
require_relative '../ssh_connection'
require_relative '../networking'

module PlatformOps
  module JumpBoxCreator
    include PlatformOps::Logging

    def tag_resource(resource_id)
      logger.info "Tagging #{resource_id} with jump box for Env #{@environment}, identifier #{identifier}"

      tags = [{ key: 'Name', value: "Jump Box #{identifier}" },
              { key: 'JumpBoxIdentifier', value: identifier },
              { key: 'Environment', value: @environment},
              { key: 'CreatedTime', value: Time.now.to_s}]

      ec2.create_tags(resources: [resource_id], tags: tags)
    end

    def create_route_table
      route_table_id = ec2.create_route_table(vpc_id: vpc_id).route_table.route_table_id

      logger.info "Created route table #{route_table_id}"

      tag_resource(route_table_id)

      intenet_gateway_id = vpc.internet_gateways.first.internet_gateway_id

      ec2.create_route(route_table_id: route_table_id, destination_cidr_block: '0.0.0.0/0', gateway_id: intenet_gateway_id)

      logger.info "Attached route table #{route_table_id} to gateway #{intenet_gateway_id}"

      route_table_id
    end


    def create_subnet(route_table_id, cidr)
      logger.info "Creating subnet in vpc #{vpc_id} for jump box #{identifier}"

      cidr = cidr || PlatformOps::Networking.find_unused_cidr_block(vpc.cidr_block, vpc.subnets.to_a.map(&:cidr_block), 28)

      logger.info "Chose cidr block #{cidr} for new subnet"

      subnet_id = ec2.create_subnet(vpc_id: vpc_id, cidr_block: cidr).subnet.subnet_id

      logger.info "Created subnet #{subnet_id}"

      tag_resource(subnet_id)

      ec2.modify_subnet_attribute(subnet_id: subnet_id, map_public_ip_on_launch: { value: true })

      logger.info "Enabled automatic public IPs for subnet #{subnet_id}"

      ec2.associate_route_table(subnet_id: subnet_id, route_table_id: route_table_id)

      logger.info "Attached route table #{route_table_id} to subnet #{subnet_id}"

      subnet_id
    end

    def create_security_group(connections)
      logger.info "Creating security group for jump box #{identifier}"

      security_group_id = vpc.create_security_group({
                                                        group_name: "JUMP-BOX-#{identifier}",
                                                        description: "Jump box #{identifier} security group"
                                                    }).group_id

      tag_resource(security_group_id)

      logger.info "Created security group #{security_group_id}"

      create_ingress_rules(security_group_id)

      unless connections.empty?
        connections.each do |connection|
          permissions = [{
              ip_protocol: 'tcp',
              from_port: connection[:port],
              to_port: connection[:port],
              user_id_group_pairs: [{ group_id: security_group_id }]
          }]

          connected_security_groups = connections.map { |x| x[:security_group_id] }

          ec2.authorize_security_group_ingress(group_id: connection[:security_group_id], ip_permissions: permissions)

          logger.info "Opened port #{connection[:port]} from #{security_group_id} to #{connected_security_groups}"
        end
      end

      security_group_id
    end

    def create_ingress_rules(security_group_id)
      ingress_cidrs.each do |cidr|
        ec2.authorize_security_group_ingress(
          group_id: security_group_id,
          ip_protocol: 'tcp',
          from_port: 22,
          to_port: 22,
          cidr_ip: cidr
        )
        logger.info "Opened port 22 from #{cidr} to security group #{security_group_id}"
      end
    end

    def create_instance(subnet_id, security_group_id)
      logger.info "Creating instance for jump box #{identifier} from image #{ami_id}"

      settings = {
          image_id: ami_id,
          min_count: 1,
          max_count: 1,
          security_group_ids: [security_group_id],
          subnet_id: subnet_id,
          user_data: user_data,
          instance_type: instance_type,
          monitoring: {
              enabled: true
          }
      }

      instance_id = ec2.run_instances(settings).instances[0].instance_id

      logger.info "Created instance #{instance_id}"

      tag_resource(instance_id)

      instance_id
    end

    def user_data
      args = OpenStruct.new(public_key: IO.read(File.expand_path(ssh_public_key_path)).strip)

      template = <<EOF
#cloud-config
ssh_authorized_keys:
  - "<%= public_key %>"
EOF

      data_str = ::ERB.new(template).result(args.instance_eval { binding })

      Base64.encode64(data_str)
    end

    def wait_for_instance(instance_id)
      helper = PlatformOps::InstanceHelpers.new(ec2)
      helper.poll_instance_running(instance_id)
      instance = helper.get_instance_by_id(instance_id)
      host = ssh_poll_private_ip ? instance.private_ip_address : instance.public_ip_address

      ssh_config = {
        host: host,
        user: ssh_user,
        timeout: 30,
        key_files: [ssh_private_key_path]
      }

      PlatformOps::SshConnection.new(ssh_config).poll_ssh

      logger.info "Instance #{instance_id} available to SSH: #{ssh_user}@#{host}"

      instance
    end

    def associate_eip(instance_id)
      ec2.associate_address(
        instance_id: instance_id,
        allocation_id: eip_allocation_id
      )
      logger.info "Instance #{instance_id} is associated with Elastic IP #{eip_allocation_id}"
    end
  end
end
