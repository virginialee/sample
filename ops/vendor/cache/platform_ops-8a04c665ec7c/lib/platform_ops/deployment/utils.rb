require 'retryable'
require_relative 'errors'
require_relative '../logging'

module PlatformOps
  module Deployment
    # Contains methods for locating AWS resources for deployments
    # 'Find' methods ending with a ! will throw exceptions when resources are not found, rather than returning nil / []
    module Utils
      include PlatformOps::Logging

      def aws_client_options
        raise "Required property @aws_client_options is missing from #{self.class.name}" unless @aws_client_options
        @aws_client_options
      end

      def auto_scaling_client
        @auto_scaling ||= Aws::AutoScaling::Client.new(aws_client_options)
      end

      def elb_client
        @elb ||= Aws::ElasticLoadBalancing::Client.new(aws_client_options)
      end

      def ec2_client
        @ec2 ||= Aws::EC2::Client.new(aws_client_options)
      end

      def cloudwatch_client
        @cloud_watch ||= Aws::CloudWatch::Client.new(aws_client_options)
      end

      def find_auto_scaling_group(group_name)
        groups = auto_scaling_client.describe_auto_scaling_groups(
          auto_scaling_group_names: [group_name],
          max_records: 2
        ).auto_scaling_groups

        return nil if groups.length == 0

        raise "More than 1 auto scaling group with the name #{group_name}" if groups.length > 1

        groups[0]
      end

      def find_auto_scaling_group!(group_name)
        group = find_auto_scaling_group(group_name)

        raise "Cannot find auto scaling group #{group_name}" unless group

        group
      end

      def find_security_group(security_group_name)
        groups = ec2_client.describe_security_groups(
          filters: [
            {name: 'group-name', values: [security_group_name]}
          ]
        ).security_groups

        raise "More than 1 security group with the name #{security_group_name}" if groups.length > 1

        groups[0]
      end

      def find_security_group!(security_group_name)
        group = find_security_group(security_group_name)

        raise "Cannot find security group #{security_group_name}" unless group

        group
      end

      def find_subnets(vpc_id, subnet_name_prefix)
        vpc_subnets = ec2_client.describe_subnets(
          filters: [
            {name: 'vpc-id', values: [vpc_id]}
          ]
        ).subnets

        vpc_subnets.select do |subnet|
          subnet.tags.any? do |tag|
            tag.key == 'Name' && tag.value && tag.value.start_with?(subnet_name_prefix)
          end
        end
      end

      def find_subnets!(vpc_id, subnet_name_prefix)
        subnets = find_subnets(vpc_id, subnet_name_prefix)

        raise "Cannot find any subnets that start with #{subnet_name_prefix}" if subnets.length == 0

        subnets
      end

      def find_vpc(vpc_name)
        vpcs = ec2_client.describe_vpcs(
          filters: [
            {name: 'tag:Name', values: [vpc_name]}
          ]
        ).vpcs

        raise "More than 1 VPC with the name #{vpc_name}" if vpcs.length > 1

        vpcs[0]
      end

      def find_vpc!(vpc_name)
        vpc = find_vpc(vpc_name)

        raise "Cannot find VPC #{vpc_name}" unless vpc

        vpc
      end

      def await_asg_instance_count(asg_name, elb_name, tries=40, sleep=10)
        raise ArgumentError unless block_given?

        Retryable.retryable(tries: tries, sleep: sleep, on: StateUnmatchedError) do |retries, exception|
          logger.info "Attempt ##{retries} but state unmatched: #{exception}" if retries > 0

          asg_instances = asg_instances_with_health(asg_name)
          elb_instances = elb_instances_with_health(elb_name)

          up_count = asg_instances.count do |id, healthy|
            healthy && elb_instances[id]
          end
          down_count = asg_instances.size - up_count

          unless yield(up_count, down_count, asg_instances.size)
            raise StateUnmatchedError, "InService: #{up_count} OutOfService: #{down_count}"
          end
        end
      end

      def elb_instances_with_health(elb_name)
        elb_client.describe_instance_health(load_balancer_name: elb_name).instance_states.inject({}) do |result, i|
          result.merge(i.instance_id => i.state == 'InService')
        end
      end

      def asg_instances_with_health(asg_name)
        find_auto_scaling_group!(asg_name).instances.inject({}) do |result, i|
          result.merge(i.instance_id => i.health_status == 'Healthy' && i.lifecycle_state == 'InService')
        end
      end

      def create_unique_launch_configuration_name(base_name)
        loop do
          name = "#{base_name}-#{SecureRandom.hex(2)}"
          existing_launch_configurations = auto_scaling_client.describe_launch_configurations(
            launch_configuration_names: [name],
            max_records: 1
          ).launch_configurations

          return name if existing_launch_configurations.length == 0

          logger.info "Launch config name #{name} already exists. Trying another one."
        end
      end

      def apply_auto_scaling_configuration(asg_name, alarm_prefix, config)
        logger.info "Setting up scaling alarms on auto scaling group #{asg_name}"
        AutoScalingConfigurator.new(config).apply_configuration(asg_name, alarm_prefix)
      end

      def delete_auto_scaling_configuration(asg_name, alarm_prefix, config)
        logger.info "Deleting scaling alarms on auto scaling group #{asg_name}"
        AutoScalingConfigurator.new(config).remove_configuration(asg_name, alarm_prefix)
      end

      def create_launch_configuration(launch_configuration_name, security_group_name, iam_profile_name, config)
        security_group = find_security_group!(security_group_name)

        settings = {
          launch_configuration_name: launch_configuration_name,
          image_id: config[:ami],
          key_name: config[:keypair_name],
          security_groups: [security_group.group_id],
          instance_type: config[:instance_type],
          iam_instance_profile: iam_profile_name,
          associate_public_ip_address: true
        }

        settings[:user_data] = Base64.encode64(config[:user_data]) if config[:user_data]

        auto_scaling_client.create_launch_configuration(settings)

        logger.info "Created launch configuration #{launch_configuration_name}"
      end

      def create_auto_scaling_group(name, min_size, max_size, launch_config_name, resources)
        vpc = find_vpc!(resources[:vpc_name])
        app_subnets = find_subnets!(vpc.vpc_id, resources[:app_subnet_name_prefix])
        availability_zones = app_subnets.map { |subnet| subnet.availability_zone }
        availability_zones = availability_zones.uniq.sort
        app_subnet_ids = app_subnets.map { |subnet| subnet.subnet_id }

        settings = {
          auto_scaling_group_name: name,
          min_size: min_size,
          max_size: max_size,
          launch_configuration_name: launch_config_name,
          default_cooldown: 60,
          availability_zones: availability_zones,
          load_balancer_names: [resources[:elb_name]],
          health_check_type: 'ELB',
          health_check_grace_period: 600,
          vpc_zone_identifier: app_subnet_ids.join(','),
          tags: [
            {
              resource_id: name,
              resource_type: 'auto-scaling-group',
              key: 'Name',
              value: "#{name}-instance",
              propagate_at_launch: true
            },
          ],
        }

        auto_scaling_client.create_auto_scaling_group(settings)

        logger.info "Created auto scaling group #{name} as #{JSON.pretty_generate(settings)}"
      end

      def delete_auto_scaling_group(asg_name)
        logger.info "Deleting auto scaling group #{asg_name}"

        20.times do |retries|
          begin
            auto_scaling_client.delete_auto_scaling_group(
              auto_scaling_group_name: asg_name
            )
            break
          rescue Aws::AutoScaling::Errors::ValidationError
            if retries > 0
              break # already gone
            else
              raise # otherwise it is a legit error
            end
          rescue Aws::AutoScaling::Errors::ServiceError => e
            if e.code == 'ScalingActivityInProgress' || e.code == 'ResourceInUse'
              logger.info "Attempt ##{retries} but: #{e.code}"
              sleep 15
            else
              raise
            end
          end
        end

        logger.info "Deleted auto scaling group #{asg_name}"
      end

      def delete_launch_configuration(name)
        auto_scaling_client.delete_launch_configuration(
          launch_configuration_name: name
        )

        logger.info "Deleted launch configuration #{name}"
      end

      def only_these_asgs!(load_balancer_name, asg_names)
        results = auto_scaling_client.describe_auto_scaling_groups(max_records: 100).auto_scaling_groups

        invalid_asgs = results.select do |asg|
          asg.load_balancer_names.member?(load_balancer_name) && !asg_names.member?(asg.auto_scaling_group_name)
        end

        unless invalid_asgs.empty?
          invalid_asg_names = invalid_asgs.map(&:auto_scaling_group_name)
          raise "The ASGs #{invalid_asg_names} are not in the whitelist for load balancer #{load_balancer_name}"
        end
      end
    end
  end
end
