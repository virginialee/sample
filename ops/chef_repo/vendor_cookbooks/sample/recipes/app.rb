include_recipe 'myob-base'
include_recipe 'java'
include_recipe 'awscli'

include_recipe 'sample::cloudwatch_logs_agent'

package 'unzip'

app_user = node['sample']['app_user']

directory '/var/log/app' do
  owner app_user
  group app_user
  mode '0755'
end
