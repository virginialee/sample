package 'ssl-cert'

app_user = 'ubuntu'
app_user_home = File.join('', 'home', app_user)

ssh_keys = data_bag_item('ssh_keys', 'sample')
npm_secrets = data_bag_item('npm', 'credentials')['authToken']

directory "#{app_user} ssh directory" do
  path File.join(app_user_home, '.ssh')
  owner app_user
  group app_user
  mode '0755'
end

file "#{app_user} id_rsa private key" do
  path File.join(app_user_home, '.ssh', 'id_rsa')
  content ssh_keys['private']
  owner app_user
  group app_user
  mode '0600'
  sensitive true
end

file "#{app_user} id_rsa public key" do
  path File.join(app_user_home, '.ssh', 'id_rsa.pub')
  content ssh_keys['public']
  owner app_user
  group app_user
  mode '0600'
end

file "#{app_user} ssh config" do
  path File.join(app_user_home, '.ssh', 'config')
  content <<EOF
Host github.com
StrictHostKeyChecking no
EOF
  mode '0755'
  owner app_user
  group app_user
end

group 'ssl-cert' do
  action :modify
  members app_user
  append true
end

bash 'add internal npm registry' do
  user app_user
  group app_user
  environment ({'HOME' => app_user_home})
  code <<-EOH
echo '@myob:registry=https://npm.addevcloudservices.com.au/' > ~/.npmrc &&
echo '//npm.addevcloudservices.com.au/:_authToken="#{npm_secrets}"' >> ~/.npmrc
  EOH
end

