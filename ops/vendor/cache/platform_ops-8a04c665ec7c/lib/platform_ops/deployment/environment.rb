require 'json'
require 'aws-sdk-core'
require 'securerandom'
require_relative '../logging'
require_relative '../utils'
require_relative 'utils'
require_relative 'errors'
require_relative 'auto_scaling_configurator'

module PlatformOps
  module Deployment
    class Environment
      include PlatformOps::Logging, PlatformOps::Deployment::Utils

      def initialize(asg_name, alarm_prefix, config)
        @config = PlatformOps::Utils.validated_config config, %i(stack_name ami source_revision keypair_name instance_type autoscaling_min autoscaling_max resources)
        @resources = PlatformOps::Utils.validated_config config[:resources], %i(elb_name app_security_group_name iam_profile_name vpc_name app_subnet_name_prefix sns_alert_name)

        @aws_client_options = PlatformOps::Utils.aws_client_options(@config)

        @asg_name = asg_name
        @alarm_prefix = alarm_prefix
      end

      def exists?
        !find_auto_scaling_group(@asg_name).nil?
      end

      def create
        lc_name = create_unique_launch_configuration_name("#{@config[:stack_name]}-launch")

        begin
          create_launch_configuration(
            lc_name,
            @resources[:app_security_group_name],
            @resources[:iam_profile_name],
            @config)

          create_auto_scaling_group(@asg_name, @config[:autoscaling_min], @config[:autoscaling_max], lc_name, @resources)

          apply_auto_scaling_configuration(@asg_name, @alarm_prefix, @config)

          wait_for_asg_scale_up(@config[:autoscaling_min])
        rescue
          logger.error "Rolling back environment #{@asg_name} because of an error."
          destroy(lc_name)
          raise
        end

        logger.info "ASG #{@asg_name} is deployed, with #{@config[:autoscaling_min]} healthy instances"
      end

      def scale_up(size)
        max_size = find_auto_scaling_group!(@asg_name).max_size

        if size > max_size
          logger.info "Scaling #{@asg_name} to max size (#{max_size})"
          size = max_size
        else
          logger.info "Scaling #{@asg_name} to size #{size}"
        end

        auto_scaling_client.set_desired_capacity(
          auto_scaling_group_name: @asg_name,
          desired_capacity: size
        )

        wait_for_asg_scale_up(size)
      end

      def drain
        logger.info "Draining auto scaling group #{@asg_name}"

        auto_scaling_client.update_auto_scaling_group(
          auto_scaling_group_name: @asg_name,
          min_size: 0,
          max_size: 0,
          desired_capacity: 0
        )

        logger.info "Waiting for auto scaling group #{@asg_name} to drain"
        await_asg_instance_count(@asg_name, @resources[:elb_name]) { |_, _, total| total == 0 }
        logger.info "Auto scaling group #{@asg_name} has been drained"
      end

      def size
        find_auto_scaling_group!(@asg_name).desired_capacity
      end

      def update
        old_lc_name = find_auto_scaling_group!(@asg_name).launch_configuration_name
        new_lc_name = create_unique_launch_configuration_name("#{@config[:stack_name]}-launch")

        logger.info "Replacing launch configuration #{old_lc_name} of #{@asg_name}"

        begin
          suspend_automatic_scaling

          create_launch_configuration(
            new_lc_name,
            @resources[:app_security_group_name],
            @resources[:iam_profile_name],
            @config)

          drain

          auto_scaling_client.update_auto_scaling_group(
            auto_scaling_group_name: @asg_name,
            min_size: @config[:autoscaling_min],
            max_size: @config[:autoscaling_max],
            launch_configuration_name: new_lc_name
          )

          logger.info "Updated auto scaling group #{@asg_name} to use launch configuration #{new_lc_name}"

          delete_launch_configuration(old_lc_name)

          wait_for_asg_scale_up(@config[:autoscaling_min])
        ensure
          resume_automatic_scaling
        end
      end

      def destroy(lc_name = nil)
        asg = find_auto_scaling_group(@asg_name)

        if asg
          suspend_automatic_scaling
          delete_auto_scaling_configuration(@asg_name, @alarm_prefix, @config)
          drain
          delete_auto_scaling_group(@asg_name)
          lc_name = asg.launch_configuration_name if lc_name.nil?
        end

        delete_launch_configuration(lc_name) if lc_name
      end

      private

      def wait_for_asg_scale_up(size)
        logger.info "Waiting for auto scaling group #{@asg_name} to scale up to #{size} instance(s)"
        await_asg_instance_count(@asg_name, @resources[:elb_name]) do |count_in_service, _, _|
          count_in_service >= size
        end
        logger.info "Auto scaling group #{@asg_name} has successfully scaled up to #{size} instance(s)"
      end

      def suspend_automatic_scaling
        auto_scaling_client.suspend_processes(
          auto_scaling_group_name: @asg_name,
          scaling_processes: ['AlarmNotification']
        )
        logger.info "Suspended AlarmNotification processes for auto scaling group #{@asg_name}"
      end

      def resume_automatic_scaling
        auto_scaling_client.resume_processes(
          auto_scaling_group_name: @asg_name,
          scaling_processes: ['AlarmNotification']
        )
        logger.info "Resumed AlarmNotification processes for auto scaling group #{@asg_name}"
      end
    end
  end
end
