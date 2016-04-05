require 'aws-sdk-core'
require 'securerandom'
require 'retryable'
require 'base64'
require_relative 'ssh_connection'
require_relative 'logging'
require_relative 'utils'

module PlatformOps
  class InstanceHelpers
    include PlatformOps::Logging

    def initialize(ec2_client)
      @ec2 = ec2_client
    end

    def get_instance_by_id(instance_id)
      result = @ec2.describe_instances(instance_ids: [instance_id])
      result.reservations[0].instances[0]
    end

    def poll_instance_running(instance_id)
      @ec2.wait_until(:instance_running, instance_ids: [instance_id]) { |waiter|
        waiter.before_wait { |attempts|
          logger.info "Starting instance #{instance_id}... Waiting #{attempts * waiter.interval} seconds"
        }
      }

      logger.info "Instance #{instance_id} is running"
      nil
    end

    def poll_instance_stopped(instance_id)
      @ec2.wait_until(:instance_stopped, instance_ids: [instance_id]) { |waiter|
        waiter.interval = 30 # number of seconds to sleep between attempts
        waiter.max_attempts = 40 # maximum number of polling attempts
        waiter.before_wait { |attempts|
          logger.info "Running cloud-init on #{instance_id}... Waiting #{attempts * waiter.interval} seconds"
        }
      }

      logger.info "Instance #{instance_id} is patched"
      nil
    end

    def poll_instance_terminated(instance_id)
      @ec2.wait_until(:instance_terminated, instance_ids: [instance_id]) { |waiter|
        waiter.before_wait { |attempts|
          logger.info "Terminating instance #{instance_id}... Waiting #{attempts * waiter.interval} seconds"
        }
      }
      logger.info "Instance #{instance_id} is terminated"
      nil
    end

    def start_instance(instance_id)
      logger.info "Restarting #{instance_id}"
      @ec2.start_instances(instance_ids: [instance_id])
      nil
    end

    def poll_ssh(instance_id, user, key_files)
      logger.info "Polling SSH on instance #{instance_id}"

      instance = get_instance_by_id(instance_id)

      ssh_config = {
          host: instance.public_ip_address,
          user: user,
          timeout: 30,
          key_files: key_files
      }

      PlatformOps::SshConnection.new(ssh_config).poll_ssh

      logger.info "Instance #{instance.instance_id} can be connected via SSH on #{instance.public_ip_address} or #{instance.public_dns_name}"
      nil
    end

    def terminate_instance(instance_id)
      @ec2.terminate_instances(instance_ids: [instance_id])
      @ec2.wait_until(:instance_terminated, instance_ids: [instance_id]) { |waiter|
        waiter.before_wait { |attempts|
          logger.info "Terminating instance #{instance_id}... Waiting #{attempts * waiter.interval} seconds"
        }
      }
      logger.info "Terminated instance #{instance_id}"
      nil
    end
  end
end
