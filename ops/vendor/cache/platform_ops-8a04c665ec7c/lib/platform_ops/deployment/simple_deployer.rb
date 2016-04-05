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
    class SimpleDeployer
      include PlatformOps::Logging, PlatformOps::Deployment::Utils

      def initialize(config)
        @config = PlatformOps::Utils.validated_config config, %i(stack_name ami source_revision keypair_name instance_type autoscaling_min autoscaling_max resources)
        @resources = PlatformOps::Utils.validated_config config[:resources], %i(elb_name app_security_group_name iam_profile_name vpc_name app_subnet_name_prefix sns_alert_name)

        @aws_client_options = PlatformOps::Utils.aws_client_options(@config)
      end

      def deploy
        only_these_asgs!(@resources[:elb_name], [asg_name])

        env = Environment.new(asg_name, asg_alarm_name_prefix, @config)
        if env.exists?
          env.update
        else
          env.create
        end
      end

      def delete
        env = Environment.new(asg_name, asg_alarm_name_prefix, @config)
        raise "Could not find an ASG with name #{asg_name}" unless env.exists?
        env.destroy
      end

      private

      def asg_name
        "#{@config[:stack_name]}-autoscaling"
      end

      def asg_alarm_name_prefix
        "#{@config[:stack_name]}-alarm-app"
      end
    end
  end
end
