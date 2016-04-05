agent_setup_file = '/opt/awslogs-agent-setup.py'

remote_file agent_setup_file do
  source node['sample']['cloudwatch_logs_agent_setup_url']
  mode '0755'
  not_if { File.exist? agent_setup_file }
end

agent_config_file = '/opt/awslogs.conf'

cookbook_file 'awslogs.conf' do
  path agent_config_file
  mode '0644'
end

execute "#{agent_setup_file} -n -r ap-southeast-2 -c #{agent_config_file}" do
  not_if 'service awslogs status'
end

