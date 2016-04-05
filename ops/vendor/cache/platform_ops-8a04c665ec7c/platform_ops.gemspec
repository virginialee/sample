# -*- encoding: utf-8 -*-
# stub: platform_ops 1.3.10 ruby lib

Gem::Specification.new do |s|
  s.name = "platform_ops"
  s.version = "1.3.10"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib"]
  s.authors = ["MYOB"]
  s.bindir = "exe"
  s.date = "2016-04-05"
  s.description = "Helper gem to manage ops of the common platform"
  s.executables = ["tfshell"]
  s.files = ["exe/tfshell", "lib/platform_ops", "lib/platform_ops/ami_builder.rb", "lib/platform_ops/ami_cleaner.rb", "lib/platform_ops/ami_deploy.rb", "lib/platform_ops/ami_finder.rb", "lib/platform_ops/certificate.rb", "lib/platform_ops/chef_cookbooks_vendorer.rb", "lib/platform_ops/chef_secret.rb", "lib/platform_ops/config_reader.rb", "lib/platform_ops/db_container.rb", "lib/platform_ops/deployment", "lib/platform_ops/deployment/auto_scaling_configurator.rb", "lib/platform_ops/deployment/environment.rb", "lib/platform_ops/deployment/errors.rb", "lib/platform_ops/deployment/rolling_deployer.rb", "lib/platform_ops/deployment/simple_deployer.rb", "lib/platform_ops/deployment/utils.rb", "lib/platform_ops/instance_helpers.rb", "lib/platform_ops/jump_box", "lib/platform_ops/jump_box.rb", "lib/platform_ops/jump_box/jump_box_creator.rb", "lib/platform_ops/jump_box/jump_box_destroyer.rb", "lib/platform_ops/letsencrypt", "lib/platform_ops/letsencrypt/Gemfile", "lib/platform_ops/letsencrypt/Gemfile.lock", "lib/platform_ops/letsencrypt/README.md", "lib/platform_ops/letsencrypt/dns_provision.rb", "lib/platform_ops/letsencrypt/ssl_cert.thor", "lib/platform_ops/letsencrypt/ssl_cert_converter.rb", "lib/platform_ops/letsencrypt/ssl_cert_issuer.rb", "lib/platform_ops/logging.rb", "lib/platform_ops/networking.rb", "lib/platform_ops/postgres_db_initializer.rb", "lib/platform_ops/ruby_db_migrator.rb", "lib/platform_ops/shell_helpers.rb", "lib/platform_ops/snapshot_cleaner.rb", "lib/platform_ops/ssh_connection.rb", "lib/platform_ops/tf_shell.rb", "lib/platform_ops/utils.rb"]
  s.rubygems_version = "2.4.8"
  s.summary = "Helper gem to manage ops of the common platform"

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<bundler>, [">= 0"])
      s.add_runtime_dependency(%q<aws-sdk-core>, ["~> 2.1"])
      s.add_runtime_dependency(%q<aws-sdk-resources>, ["~> 2.1"])
      s.add_runtime_dependency(%q<retryable>, [">= 0"])
      s.add_runtime_dependency(%q<net-ssh>, [">= 0"])
      s.add_runtime_dependency(%q<net-scp>, [">= 0"])
      s.add_runtime_dependency(%q<netaddr>, [">= 0"])
      s.add_runtime_dependency(%q<aws_helpers>, [">= 0"])
      s.add_runtime_dependency(%q<cfndsl>, [">= 0"])
      s.add_runtime_dependency(%q<chef>, [">= 0"])
      s.add_runtime_dependency(%q<berkshelf>, [">= 0"])
      s.add_runtime_dependency(%q<chef_runner>, [">= 0"])
      s.add_runtime_dependency(%q<pg>, [">= 0"])
      s.add_development_dependency(%q<rake>, [">= 0"])
      s.add_development_dependency(%q<rspec>, [">= 0"])
      s.add_development_dependency(%q<pry>, [">= 0"])
      s.add_development_dependency(%q<simplecov>, [">= 0"])
    else
      s.add_dependency(%q<bundler>, [">= 0"])
      s.add_dependency(%q<aws-sdk-core>, ["~> 2.1"])
      s.add_dependency(%q<aws-sdk-resources>, ["~> 2.1"])
      s.add_dependency(%q<retryable>, [">= 0"])
      s.add_dependency(%q<net-ssh>, [">= 0"])
      s.add_dependency(%q<net-scp>, [">= 0"])
      s.add_dependency(%q<netaddr>, [">= 0"])
      s.add_dependency(%q<aws_helpers>, [">= 0"])
      s.add_dependency(%q<cfndsl>, [">= 0"])
      s.add_dependency(%q<chef>, [">= 0"])
      s.add_dependency(%q<berkshelf>, [">= 0"])
      s.add_dependency(%q<chef_runner>, [">= 0"])
      s.add_dependency(%q<pg>, [">= 0"])
      s.add_dependency(%q<rake>, [">= 0"])
      s.add_dependency(%q<rspec>, [">= 0"])
      s.add_dependency(%q<pry>, [">= 0"])
      s.add_dependency(%q<simplecov>, [">= 0"])
    end
  else
    s.add_dependency(%q<bundler>, [">= 0"])
    s.add_dependency(%q<aws-sdk-core>, ["~> 2.1"])
    s.add_dependency(%q<aws-sdk-resources>, ["~> 2.1"])
    s.add_dependency(%q<retryable>, [">= 0"])
    s.add_dependency(%q<net-ssh>, [">= 0"])
    s.add_dependency(%q<net-scp>, [">= 0"])
    s.add_dependency(%q<netaddr>, [">= 0"])
    s.add_dependency(%q<aws_helpers>, [">= 0"])
    s.add_dependency(%q<cfndsl>, [">= 0"])
    s.add_dependency(%q<chef>, [">= 0"])
    s.add_dependency(%q<berkshelf>, [">= 0"])
    s.add_dependency(%q<chef_runner>, [">= 0"])
    s.add_dependency(%q<pg>, [">= 0"])
    s.add_dependency(%q<rake>, [">= 0"])
    s.add_dependency(%q<rspec>, [">= 0"])
    s.add_dependency(%q<pry>, [">= 0"])
    s.add_dependency(%q<simplecov>, [">= 0"])
  end
end
