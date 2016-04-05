require_relative 'spec_helper'
require_relative '../lib/platform_ops/ami_deploy'
require_relative '../lib/platform_ops/deployment/simple_deployer'

RSpec.describe PlatformOps::AmiDeploy do

  let(:simple_config) {
    {
      deployment_strategy: 'simple',
      stack_name: 'Testing',
      ami: 'Fake_AMI',
      source_revision: '2015.02.02.01',
      keypair_name: 'testing-keypair',
      instance_type: 't2.medium',
      autoscaling_min: 1,
      autoscaling_max: 4,
      resources: {
        vpc_name: 'vpc-name-test',
        elb_name: 'elb-name-test',
        app_security_group_name: 'sg-name-app',
        iam_profile_name: 'profile-name',
        app_subnet_name_prefix: 'app-subnet',
        sns_alert_name: 'alert-name'
      }
    }
  }

  describe 'constructor' do
    it 'sets the deployment strategy based on config' do
      obj = PlatformOps::AmiDeploy.new(simple_config)

      expect(obj.instance_exec { @deployer }).to be_a(PlatformOps::Deployment::SimpleDeployer)
    end

    it 'uses the simple deployment strategy if none is specified' do
      simple_config.delete(:deployment_strategy)
      obj = PlatformOps::AmiDeploy.new(simple_config)

      expect(obj.instance_exec { @deployer }).to be_a(PlatformOps::Deployment::SimpleDeployer)
    end

    it 'raises an error if the deployment strategy is unrecognised' do
      simple_config[:deployment_strategy] = :fake

      expect { PlatformOps::AmiDeploy.new(simple_config) }.to raise_error(ArgumentError)
    end
  end

  describe '#deploy' do
    it 'calls deploy on the selected strategy' do
      obj = PlatformOps::AmiDeploy.new(simple_config)

      expect_any_instance_of(PlatformOps::Deployment::SimpleDeployer).to receive(:deploy).and_return(nil)

      obj.deploy
    end
  end

  describe '#delete' do
    it 'calls delete on the selected strategy' do
      obj = PlatformOps::AmiDeploy.new(simple_config)

      expect_any_instance_of(PlatformOps::Deployment::SimpleDeployer).to receive(:delete).and_return(nil)

      obj.delete
    end
  end
end
