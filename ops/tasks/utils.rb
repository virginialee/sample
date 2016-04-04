require 'octokit'
require 'yaml'

def load_config task_file
  file_name = File.basename(task_file, '.rb')
  dir = File.dirname(task_file)
  path = File.join(dir, "#{file_name}.yml")
  YAML.load_file(path)
end

def get_latest_github_release(project, asset, github_token)
  client = Octokit::Client.new access_token: github_token
  resp = client.latest_release(project)

  asset = resp[:assets].select { |a| a.name == asset }.first

  index = asset[:url].index("api.")
  url = asset[:url][index..-1]
  asset_url = "https://#{github_token}:@#{url}"

  # TODO need to get asset name in an array or retrieve all assets in a zip
  `wget --auth-no-challenge --header='Accept:application/octet-stream' #{asset_url} -O #{asset[:name]}`

  asset[:name]
end
