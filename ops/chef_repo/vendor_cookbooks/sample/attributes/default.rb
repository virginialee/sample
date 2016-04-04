#User
default['sample']['app_user'] = 'ubuntu'
default['sample']['db_env'] = 'non-prod'
default['sample']['nginx_env'] = 'non-prod'
default['sample']['play_env'] = 'non-prod'

#Cloudwatch
default['sample']['app_name'] = 'sample'
default['sample']['cloudwatch_logs_agent_setup_url'] = 'https://s3.amazonaws.com/aws-cloudwatch/downloads/latest/awslogs-agent-setup.py'

#Java
default['java']['jdk_version'] = '8'
default['java']['install_flavor'] = 'oracle'
default['java']['oracle']['accept_oracle_download_terms'] = true
default['java']['jdk']['8']['x86_64']['url'] = 'https://s3-ap-southeast-2.amazonaws.com/myob-platform-file-hosting-syd/jdk-8u60-linux-x64.tar.gz'
default['java']['jdk']['8']['x86_64']['checksum'] = 'ebe51554d2f6c617a4ae8fc9a8742276e65af01bd273e96848b262b3c05424e5'
default['java']['ark_timeout'] = 1200

#Node
default['nodejs']['version'] = '5.5.0'
default['nodejs']['install_method'] = 'binary'
default['nodejs']['binary']['checksum'] = '3e593d91b6d2ad871efaaf8e9a17b3608ca98904959bcfb7c42e6acce89e80f4'

#Splunk
default['myob-splunk']['certificates']['data_bag_name'] = 'splunk'
default['myob-splunk']['certificates']['data_bag_item_name'] = 'certificates'
default['myob-splunk']['server_url'] = 'sink.its.myob.com:9997'
default['myob-splunk']['index'] = 'sample-dev'
default['myob-splunk']['inputs']['log_files'] = %w(/var/log/syslog /var/log/kern.log /var/log/nginx /var/log/app).map do |log_file|
  {'path' => log_file}
end

#Nginx
default['myob-nginx']['service']['name'] = 'sample'
default['myob-nginx']['service']['port'] = 9000
default['myob-nginx']['certificates']['data_bag_name'] = 'nginx'
default['myob-nginx']['certificates']['data_bag_item_name'] = node['sample']['nginx_env']
default['myob-nginx']['rate_limit'] = '10r/s'
default['myob-nginx']['rate_limit_exemptions'] = [] #List of ip's/cidr blocks (eg: mashery ips)

