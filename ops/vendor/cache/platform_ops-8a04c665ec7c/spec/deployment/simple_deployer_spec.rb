require 'aws-sdk-core'
require_relative '../spec_helper'
require_relative '../../lib/platform_ops/deployment/rolling_deployer'

RSpec.describe PlatformOps::Deployment::SimpleDeployer do
  let(:config) {
    {
      stack_name: 'test-stack_name',
      region: 'us-west-2',
      ami: 'test-ami',
      source_revision: 'test-source_revision',
      keypair_name: 'test-keypair_name',
      instance_type: 'test-instance_type',
      autoscaling_min: 'test-autoscaling_min',
      autoscaling_max: 'test-autoscaling_max',
      resources: {
        elb_name: 'test-elb_name',
        app_security_group_name: 'test-app_security_group_name',
        iam_profile_name: 'test-iam_profile_name',
        vpc_name: 'test-vpc_name',
        app_subnet_name_prefix: 'test-app_subnet_name_prefix',
        sns_alert_name: 'test-sns_alert_name',
      }
    }
  }

  let(:environment) {
    instance_double(PlatformOps::Deployment::Environment, create: nil, destroy: nil, scale_up: nil)
  }

  subject {
    PlatformOps::Deployment::SimpleDeployer.new(config)
  }

  before do
    allow(PlatformOps::Deployment::Environment).to receive(:new)
        .with("#{config[:stack_name]}-autoscaling", "#{config[:stack_name]}-alarm-app", anything)
        .and_return(environment)
    allow(subject).to receive(:only_these_asgs!)
  end

  describe '#deploy' do
    it 'creates the environment if it does not exist' do
      expect(environment).to receive(:exists?).and_return(false)

      expect(environment).to receive(:create)

      subject.deploy
    end

    it 'updates the environment if it exists' do
      expect(environment).to receive(:exists?).and_return(true)

      expect(environment).to receive(:update)

      subject.deploy
    end
  end

  describe '#delete' do
    it 'deletes the environment if it exists' do
      expect(environment).to receive(:exists?).and_return(true)

      expect(environment).to receive(:destroy)

      subject.delete
    end

    it 'raises an error if the environment does not exist' do
      expect(environment).to receive(:exists?).and_return(false)

      expect { subject.delete }.to raise_error
    end
  end
end
