include_recipe 'myob-base'
include_recipe 'java'
include_recipe 'awscli'

include_recipe 'myob-nginx::install'

include_recipe 'sample::cloudwatch_logs_agent'

package 'unzip'

app_user = node['sample']['app_user']

directory '/var/log/app' do
  owner app_user
  group app_user
  mode '0755'
end

app_user = 'ubuntu'
license = 'dummy'

newrelic_agent_java 'Install Newrelic Java Agent' do
  license license
  install_dir File.join('', 'home', app_user, 'newrelic')
  app_name 'Sample'
  app_user app_user
  app_group app_user
  enabled true
  execute_agent_action false
  logfile 'newrelic_agent.log'
  logfile_path '/var/log/newrelic'
end

newrelic_server_monitor 'Install' do
  license license
  service_notify_action 'nothing'
  service_actions []
end

