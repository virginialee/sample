include_recipe 'sample::cloudwatch_logs_agent_start'

include_recipe 'supervisor'

app_user = 'ubuntu'
app_user_home = File.join('', 'home', app_user)
app_user_home_dist = File.join(app_user_home, 'dist')

properties = node['sample']['properties'].merge(
    "play.crypto.secret" => "sample_crypto_secret"
).map { |k,v| "-D#{k}=#{v}" }.join(' ')

supervisor_service 'sample' do
  directory app_user_home_dist
  stdout_logfile '/var/log/app/sample_out.log'
  stderr_logfile '/var/log/app/sample_err.log'
  command "sudo -H -u #{app_user} bash -l -c \"./bin/sample-api #{properties} #{jvm_configuration}\""
end

service 'nginx' do
  supports :restart => true
  action [ :enable, :start ]
end

service 'supervisor' do
  supports :restart => true
  action [ :enable, :start  ]
end

