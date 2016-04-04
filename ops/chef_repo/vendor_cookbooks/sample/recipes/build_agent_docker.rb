include_recipe 'myob-base'
include_recipe 'git'
package 'openjdk-7-jre-headless'
include_recipe 'awscli'

include_recipe 'sample::users'

include_recipe 'myob-app-base::ubuntu_docker'
include_recipe 'myob-app-base::docker_compose'

# Prebuild

app_user = node['sample']['app_user']
app_user_home = File.join('', 'home', app_user)
app_user_home_src = File.join(app_user_home, 'sample')
app_user_home_api = File.join(app_user_home_src, 'api')
app_user_home_ops = File.join(app_user_home_src, 'ops')

# checkout sample src, assuming it has the largest set of dependencies

#git app_user_home_src do
#  repository 'git@github.com:virginialee/sample.git'
#  revision 'HEAD'
#  user app_user
#  group app_user
#  action :sync
#end
#
## simulate what jenkins job does
#bash 'tar and untar src' do
#  code <<-EOH
#    set -ex
#    tar -czf workspace.tar.gz  --exclude='*.tar.gz' --exclude-vcs sample/*
#    rm -rf sample
#    tar -xzf workspace.tar.gz
#    rm workspace.tar.gz
#  EOH
#  cwd app_user_home
#end
#
## pull before build to avoid invalidating build cache
#execute 'docker-compose -p sample-base-api pull --ignore-pull-failure' do
#  cwd app_user_home_api
#  user app_user
#  group 'docker'
#  retries 3
#end
#
#execute 'docker-compose -p sample-base-ops pull --ignore-pull-failure' do
#  cwd app_user_home_ops
#  user app_user
#  group 'docker'
#  retries 3
#end
#
## build
#execute 'docker-compose -p sample-base-api build' do
#  cwd app_user_home_api
#  user app_user
#  group 'docker'
#  retries 3
#end
#
#execute 'docker-compose -p sample-base-ops build' do
#  cwd app_user_home_ops
#  user app_user
#  group 'docker'
#  retries 3
#end
#
## cleanup src
#
#directory app_user_home_src do
#  recursive true
#  action :delete
#end

# cleanup sensitive data

file "#{app_user} id_rsa private key" do
  path File.join(app_user_home, '.ssh', 'id_rsa')
  action :delete
  backup false
end

# prepare init script

package 'jq' # this is used for parsing json result

cookbook_file 'build_agent_docker_init.sh' do
  path '/opt/build_agent_docker_init.sh'
  mode '0755'
end
