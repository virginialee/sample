agent_config_file = '/var/awslogs/etc/awslogs.conf'

service 'awslogs' do
  action :nothing
  supports :status => true, :start => true, :stop => true, :restart => true
end

template agent_config_file do
  source 'awslogs.conf.erb'
  mode '0644'
  variables :app_name => node['sample']['app_name']
end

