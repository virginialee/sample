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

module PlatformOps
  module JumpBoxDestroyer
    include PlatformOps::Logging

    def find_resources_by_tag
      logger.info "Searching for resources with jump box id #{identifier}"

      search_criteria = {
          filters: [
              { name: 'key', values: ['JumpBoxIdentifier'] },
              { name: 'value', values: [ identifier ] }
          ],
          max_results: 10
      }

      result = ec2.describe_tags(search_criteria).map {|r| r.tags }.flatten(1)

      logger.info "Found #{result.length} resources with jump box id #{identifier}"

      find_resource_id = lambda do |resource_type|
        resource = result.find { |r| r.resource_type == resource_type }
        resource.nil? ? nil : resource.resource_id
      end

      resources = {}
      resources[:instance] = find_resource_id.call('instance')
      resources[:security_group] = find_resource_id.call('security-group')
      resources[:subnet] = find_resource_id.call('subnet')
      resources[:route_table] = find_resource_id.call('route-table')
      resources
    end

    def destroy_instance(resources)
      unless resources[:instance].nil?
        # Because terminated instances can still be searched by tag for a while,
        # we need to untag it so that we won't find it again.
        untag_resource(resources[:instance])

        helper = PlatformOps::InstanceHelpers.new(ec2)

        logger.info "Terminating instance #{resources[:instance]}"

        ec2.terminate_instances(instance_ids: [resources[:instance]])
        helper.poll_instance_terminated(resources[:instance])

        logger.info "Terminated instance #{resources[:instance]}"
      end
    end

    def destroy_security_group(resources)
      unless resources[:security_group].nil?
        destroy_references_to_security_group(resources)

        logger.info "Deleting security group #{resources[:security_group]}"

        ec2.delete_security_group(group_id: resources[:security_group])

        logger.info "Deleted security group #{resources[:security_group]}"
      end
    end

    def destroy_references_to_security_group(resources)
      logger.info "Searching for references to #{resources[:security_group]}"

      connected_groups = ec2.describe_security_groups({
                                       filters: [{
                                                     name: 'ip-permission.group-id',
                                                     values: [resources[:security_group]]
                                                 }]
                                   }).security_groups

      logger.info "Found #{connected_groups.length} security groups which reference #{resources[:security_group]}"

      connected_groups.each do |group|
        filtered_permissions = group.ip_permissions.map do |permission|
          filtered_pairs = permission.user_id_group_pairs.select { |pair| pair.group_id == resources[:security_group] }

          if filtered_pairs.any?
            {
                ip_protocol: permission.ip_protocol,
                from_port: permission.from_port,
                to_port: permission.to_port,
                user_id_group_pairs: filtered_pairs
            }
          else
            nil
          end
        end.compact

        logger.info "Revoking access from #{resources[:security_group]} to #{group.group_id}"

        ec2.revoke_security_group_ingress(group_id: group.group_id, ip_permissions: filtered_permissions)
      end

      logger.info "Finished cleaning up references to #{resources[:security_group]}"
    end

    def destroy_subnet(resources)
      unless resources[:subnet].nil?
        logger.info "Deleting subnet #{resources[:subnet]}"

        ec2.delete_subnet(subnet_id: resources[:subnet])

        logger.info "Deleted subnet #{resources[:subnet]}"
      end
    end

    def destroy_route_table(resources)
      unless resources[:route_table].nil?
        logger.info "Deleting route table #{resources[:route_table]}"

        ec2.delete_route_table(route_table_id: resources[:route_table])

        logger.info "Deleted route table #{resources[:route_table]}"
      end
    end

    def untag_resource(resource_id)
      logger.info "Untagging #{resource_id} with jump box identifier #{identifier}"

      tags = [{ key: 'Name', value: "Jump Box #{identifier}" }, { key: 'JumpBoxIdentifier', value: identifier }]
      ec2.delete_tags(resources: [resource_id], tags: tags)
    end
  end
end
