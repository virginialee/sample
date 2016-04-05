require 'fileutils'
require 'berkshelf'

module PlatformOps
  class ChefCookbooksVendorer
    def initialize(chef_repo_path, vendored_cookbooks_path='cookbooks')
      @chef_repo_path = chef_repo_path
      @vendored_cookbooks_path = vendored_cookbooks_path
    end

    def vendor_chef_repo
      Dir.chdir(@chef_repo_path) do
        FileUtils.rm_rf(@vendored_cookbooks_path)
        berksfile = ::Berkshelf::Berksfile.from_file('Berksfile')
        berksfile.vendor(@vendored_cookbooks_path)
      end
    end
  end
end
