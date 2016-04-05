require 'json'
require 'aws-sdk-core'
require 'securerandom'
require_relative '../logging'
require_relative '../utils'
require_relative 'utils'
require_relative 'errors'
require_relative 'auto_scaling_configurator'
require_relative 'environment'

module PlatformOps
  module Deployment
    class RollingDeployer
      include PlatformOps::Logging, PlatformOps::Deployment::Utils

      def initialize(config)
        @config = PlatformOps::Utils.validated_config config, %i(stack_name ami source_revision keypair_name instance_type autoscaling_min autoscaling_max resources)
        @resources = PlatformOps::Utils.validated_config config[:resources], %i(elb_name app_security_group_name iam_profile_name vpc_name app_subnet_name_prefix sns_alert_name)

        @aws_client_options = PlatformOps::Utils.aws_client_options(@config)
      end

      def deploy
        only_these_asgs!(@resources[:elb_name], [asg_name('blue'), asg_name('green')])

        blue_deployment = Environment.new(asg_name('blue'), alarm_prefix('blue'), @config)
        green_deployment = Environment.new(asg_name('green'), alarm_prefix('green'), @config)

        logger.info "Checking for existing blue AutoScaling Group '#{asg_name('blue')}'"
        logger.info "Checking for existing green AutoScaling Group '#{asg_name('green')}'"

        blue_exists = blue_deployment.exists?
        green_exists = green_deployment.exists?

        error_msg = 'Both blue and green AutoScaling Groups already exist. Is another deployment in progress?'
        raise error_msg if blue_exists && green_exists

        if blue_exists
          logger.info 'Found blue - moving to green'
          green_deployment.create
          green_deployment.scale_up(blue_deployment.size)
          blue_deployment.destroy
        elsif green_exists
          logger.info 'Found green - moving to blue'
          blue_deployment.create
          blue_deployment.scale_up(green_deployment.size)
          green_deployment.destroy
        else
          logger.info 'Found nothing - moving to blue'
          blue_deployment.create
        end
      end

      def delete
        blue_deployment = Environment.new(asg_name('blue'), alarm_prefix('blue'), @config)
        green_deployment = Environment.new(asg_name('green'), alarm_prefix('green'), @config)

        blue_exists = blue_deployment.exists?
        green_exists = green_deployment.exists?

        error_msg = 'Both blue and green AutoScaling Groups already exist. Is a deployment in progress?'
        raise error_msg if blue_exists && green_exists

        if blue_exists
          blue_deployment.destroy
        elsif green_exists
          green_deployment.destroy
        end
      end

      private

      def asg_name(env)
        "#{@config[:stack_name]}-autoscaling-#{env}"
      end

      def alarm_prefix(env)
        "#{asg_name(env)}-alarms"
      end
    end
  end
end
