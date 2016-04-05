require 'aws-sdk-core'
require_relative '../logging'
require_relative 'utils'

module PlatformOps
  module Deployment
    class AutoScalingConfigurator
      include PlatformOps::Logging

      def initialize(config)
        @config = PlatformOps::Utils.validated_config config, %i(stack_name instance_type resources)
        @resources = PlatformOps::Utils.validated_config config[:resources], %i(elb_name app_security_group_name iam_profile_name vpc_name app_subnet_name_prefix sns_alert_name)

        client_options = PlatformOps::Utils.aws_client_options(@config)

        @auto_scaling = Aws::AutoScaling::Client.new(client_options)
        @cloud_watch = Aws::CloudWatch::Client.new(client_options)
        @sns = Aws::SNS::Client.new(client_options)
      end

      def apply_configuration(asg_name, asg_alarm_name_prefix)
        policy_arns = put_scaling_policies(asg_name)
        alert_arn = put_sns_alert
        put_alarms(asg_name, asg_alarm_name_prefix, policy_arns, alert_arn)
      end

      def remove_configuration(asg_name, asg_alarm_name_prefix)
        delete_alarms(asg_name, asg_alarm_name_prefix)
        delete_scaling_policies(asg_name)
      end

      private

      def put_scaling_policies(asg_name)
        policies = {
          up: {
            cooldown: 300,
            scaling_adjustment: 1
          },

          down: {
            cooldown: 1800,
            scaling_adjustment: -1
          }
        }

        arns = policies.map do |key, data|
          settings = {
            auto_scaling_group_name: asg_name,
            policy_name: "#{asg_name}-#{key}",
            policy_type: 'SimpleScaling',
            adjustment_type: 'ChangeInCapacity',
            scaling_adjustment: data[:scaling_adjustment],
            cooldown: data[:cooldown]
          }

          arn = @auto_scaling.put_scaling_policy(settings).policy_arn

          logger.info "Configured auto scaling policy as #{JSON.pretty_generate(settings)}"

          [key, arn]
        end

        arns.to_h
      end

      def put_alarms(asg_name, asg_alarm_name_prefix, policy_arns, alert_arn)
        thresholds = alarms_thresholds

        @cloud_watch.put_metric_alarm(
          alarm_name: "#{asg_alarm_name_prefix}-cpu-up",
          alarm_description: "#{@config[:stack_name]} - Scale up alarm when CPU utilization is greater than a certain amount (based on instance type) for 3 periods of 1 minute",
          alarm_actions: [policy_arns[:up]],
          comparison_operator: "GreaterThanThreshold",
          evaluation_periods: 3,
          metric_name: "CPUUtilization",
          namespace: "AWS/EC2",
          period: 60,
          statistic: "Average",
          threshold: thresholds[:cpu_up][:instance_types][@config[:instance_type]],
          unit: 'Percent',
          dimensions: [{name: 'AutoScalingGroupName', value: asg_name}]
        )

        @cloud_watch.put_metric_alarm(
          alarm_name: "#{asg_alarm_name_prefix}-cpu-down",
          alarm_description: "#{@config[:stack_name]} - Scale down alarm when CPU utilization is less than a certain amount (based on instance type) for 6 periods of 5 minutes",
          alarm_actions: [policy_arns[:down]],
          comparison_operator: "LessThanThreshold",
          evaluation_periods: 6,
          metric_name: "CPUUtilization",
          namespace: "AWS/EC2",
          period: 300,
          statistic: "Average",
          threshold: thresholds[:cpu_down][:instance_types][@config[:instance_type]],
          unit: 'Percent',
          dimensions: [{name: 'AutoScalingGroupName', value: asg_name}]
        )

        @cloud_watch.put_metric_alarm(
          alarm_name: "#{asg_alarm_name_prefix}-network-out-down",
          alarm_description: "#{@config[:stack_name]} - Scale down alarm when NetworkOut is less than 750000 for 6 periods of 5 minute",
          alarm_actions: [policy_arns[:down]],
          comparison_operator: "LessThanThreshold",
          evaluation_periods: 6,
          metric_name: "NetworkOut",
          namespace: "AWS/EC2",
          period: 300,
          statistic: "Average",
          threshold: 750000,
          dimensions: [{name: 'AutoScalingGroupName', value: asg_name}]
        )

        @cloud_watch.put_metric_alarm(
          alarm_name: "#{asg_alarm_name_prefix}-network-out-up",
          alarm_description: "#{@config[:stack_name]} - Scale up alarm when NetworkOut is more than 30000000 for 3 periods of 1 minute",
          alarm_actions: [policy_arns[:up]],
          comparison_operator: "GreaterThanThreshold",
          evaluation_periods: 3,
          metric_name: "NetworkOut",
          namespace: "AWS/EC2",
          period: 60,
          statistic: "Average",
          threshold: 30000000,
          dimensions: [{name: 'AutoScalingGroupName', value: asg_name}]
        )

        @cloud_watch.put_metric_alarm(
          alarm_name: "#{asg_alarm_name_prefix}-network-in-down",
          alarm_description: "#{@config[:stack_name]} - Scale down alarm when NetworkIn is less than 750000 for 6 periods of 5 minute",
          alarm_actions: [policy_arns[:down]],
          comparison_operator: "LessThanThreshold",
          evaluation_periods: 6,
          metric_name: "NetworkIn",
          namespace: "AWS/EC2",
          period: 300,
          statistic: "Average",
          threshold: 750000,
          dimensions: [{name: 'AutoScalingGroupName', value: asg_name}]
        )

        @cloud_watch.put_metric_alarm(
          alarm_name: "#{asg_alarm_name_prefix}-network-in-up",
          alarm_description: "#{@config[:stack_name]} - Scale up alarm when NetworkIn is more than 30000000 for 3 periods of 1 minute",
          alarm_actions: [policy_arns[:up]],
          comparison_operator: "GreaterThanThreshold",
          evaluation_periods: 3,
          metric_name: "NetworkIn",
          namespace: "AWS/EC2",
          period: 60,
          statistic: "Average",
          threshold: 30000000,
          dimensions: [{name: 'AutoScalingGroupName', value: asg_name}]
        )

        @cloud_watch.put_metric_alarm(
          alarm_name: "#{asg_alarm_name_prefix}-credit-min",
          alarm_description: "#{@config[:stack_name]} - Alarm when credits fall below minimum",
          alarm_actions: [alert_arn],
          comparison_operator: "LessThanThreshold",
          evaluation_periods: 1,
          metric_name: "CPUCreditBalance",
          namespace: "AWS/EC2",
          period: 120,
          statistic: "Minimum",
          threshold: thresholds[:credit][:instance_types][@config[:instance_type]],
          dimensions: [{name: 'AutoScalingGroupName', value: asg_name}]
        )

        @cloud_watch.put_metric_alarm(
          alarm_name: "#{asg_alarm_name_prefix}-credit-avg",
          alarm_description: "#{@config[:stack_name]} - Alarm when average credits fall below minimum",
          alarm_actions: [alert_arn],
          comparison_operator: "LessThanThreshold",
          evaluation_periods: 1,
          metric_name: "CPUCreditBalance",
          namespace: "AWS/EC2",
          period: 120,
          statistic: "Average",
          threshold: thresholds[:credit][:instance_types][@config[:instance_type]],
          dimensions: [{name: 'AutoScalingGroupName', value: asg_name}]
        )

        @cloud_watch.put_metric_alarm(
          alarm_name: "#{asg_alarm_name_prefix}-mem",
          alarm_description: "#{@config[:stack_name]} - Alarm when RAM falls below a certain amount (in MB)",
          alarm_actions: [alert_arn],
          comparison_operator: "LessThanThreshold",
          evaluation_periods: 1,
          metric_name: "MemoryAvailable",
          namespace: "System/Linux",
          period: 300,
          statistic: "Average",
          threshold: thresholds[:mem][:instance_types][@config[:instance_type]],
          dimensions: [{name: 'AutoScalingGroupName', value: asg_name}]
        )

        @cloud_watch.put_metric_alarm(
          alarm_name: "#{asg_alarm_name_prefix}-disk",
          alarm_description: "#{@config[:stack_name]} - Alarm when free disk space falls below a certain amount (in GB)",
          alarm_actions: [alert_arn],
          comparison_operator: "LessThanThreshold",
          evaluation_periods: 1,
          metric_name: "DiskSpaceAvailable",
          namespace: "System/Linux",
          period: 300,
          statistic: "Average",
          threshold: thresholds[:disk][:instance_types][@config[:instance_type]],
          dimensions: [
            {name: 'AutoScalingGroupName', value: asg_name},
            {name: 'Filesystem', value: '/dev/xvda1'},
            {name: 'MountPath', value: '/'}
          ]
        )

        logger.info 'Configured auto scaling group alarms'
      end

      def put_sns_alert
        @sns.create_topic(
          name: @resources[:sns_alert_name]
        ).topic_arn
      end

      def alarms_thresholds
        {
          cpu_up: {
            description: 'Maximum CPU usage threshold based on the instance type. Above this level, an alarm will be generated to indicate a need for more resources.',
            instance_types: {
              't2.medium' => 35
            }
          },

          cpu_down: {
            description: 'Minimum CPU usage threshold based on the instance type. Below this level, an alarm will be generated to indicate a need for less resources.',
            instance_types: {
              't2.medium' => 10
            }
          },

          mem: {
            description: 'Free RAM threshold based on the instance type. Below this level, an alarm will be generated.',
            instance_types: {
              't2.medium' => 500
            }
          },

          disk: {
            description: 'Free diskspace threshold based on the instance type. Below this level, an alarm will be generated.',
            instance_types: {
              't2.medium' => 1.5
            }
          },

          credit: {
            description: 'CPU credit balance. Only applicable to t2 instances',
            instance_types: {
              't2.medium' => 55
            }
          }
        }
      end

      def delete_alarms(asg_name, asg_alarm_name_prefix)
        alarms = @cloud_watch.describe_alarms(
          alarm_name_prefix: asg_alarm_name_prefix
        ).map do |response|
          response.metric_alarms.select do |alarm|
            alarm.dimensions.any? do |dimension|
              dimension.name == 'AutoScalingGroupName' && dimension.value == asg_name
            end
          end
        end.flatten(1)

        alarm_names = alarms.map { |alarm| alarm.alarm_name }

        @cloud_watch.delete_alarms(
          alarm_names: alarm_names
        )

        logger.info "Deleted #{alarm_names.length} auto scaling group alarms: #{alarm_names}"
      end

      def delete_scaling_policies(asg_name)
        policies = @auto_scaling.describe_policies(
          auto_scaling_group_name: asg_name
        ).map do |response|
          response.scaling_policies
        end.flatten(1)

        policy_names = policies.map { |policy| policy.policy_name }

        policy_names.each do |policy_name|
          @auto_scaling.delete_policy(
            auto_scaling_group_name: asg_name,
            policy_name: policy_name
          )

          logger.info "Deleted auto scaling policy #{policy_name}"
        end
      end
    end
  end
end
