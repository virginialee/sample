require 'aws-sdk'

module DnsProvision
  def create_update_record_set(domain_name, hosted_zone_name, txt_challenge)
    route53 = Aws::Route53::Client.new
    hosted_zone = route53.list_hosted_zones.hosted_zones.select do |hosted_zone|
        hosted_zone.name == hosted_zone_name
    end.first
    record_set_name = "_acme-challenge.#{domain_name}."
    change = {
      action: 'UPSERT',
      resource_record_set: {
        name: record_set_name,
        type: 'TXT',
        ttl: 60,
        resource_records: [
          value: "\"#{txt_challenge}\"",
        ],
      },
    }
    route53.change_resource_record_sets(
      {hosted_zone_id: hosted_zone.id,
       change_batch: {changes: [change]}
      })
    puts "record set #{record_set_name} has been created"
  end
end