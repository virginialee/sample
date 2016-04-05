require 'aws-sdk-core'
require_relative '../spec_helper'
require_relative '../../lib/platform_ops/deployment/rolling_deployer'

RSpec.describe PlatformOps::Deployment::RollingDeployer do
  let(:config) {
    {
      stack_name: 'test-stack_name',
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

  let(:blue_asg_name) {
    "#{config[:stack_name]}-autoscaling-blue"
  }

  let(:green_asg_name) {
    "#{config[:stack_name]}-autoscaling-green"
  }

  let(:blue_env) {
    instance_double(PlatformOps::Deployment::Environment, create: nil, destroy: nil, scale_up: nil)
  }

  let(:green_env) {
    instance_double(PlatformOps::Deployment::Environment, create: nil, destroy: nil, scale_up: nil)
  }

  subject {
    PlatformOps::Deployment::RollingDeployer.new(config)
  }

  before do
    allow(PlatformOps::Deployment::Environment).to receive(:new)
        .with(blue_asg_name, "#{blue_asg_name}-alarms", anything)
        .and_return(blue_env)

    allow(PlatformOps::Deployment::Environment).to receive(:new)
        .with(green_asg_name, "#{green_asg_name}-alarms", anything)
        .and_return(green_env)
  end

  describe '#deploy' do
    before do
      expect(subject).to receive(:only_these_asgs!)
    end

    context 'both blue and green environments exist' do
      it 'raises an error because another deployment is in progress' do
        allow(blue_env).to receive(:exists?).and_return(true)
        allow(green_env).to receive(:exists?).and_return(true)

        expect { subject.deploy }.to raise_error
      end
    end

    context 'neither environment exists' do
      before do
        allow(blue_env).to receive(:exists?).and_return(false)
        allow(green_env).to receive(:exists?).and_return(false)
      end

      it 'creates a blue environment' do
        expect(blue_env).to receive(:create)

        subject.deploy
      end
    end

    context 'only blue environment exists' do
      before do
        allow(blue_env).to receive(:exists?).and_return(true)
        allow(green_env).to receive(:exists?).and_return(false)

        allow(blue_env).to receive(:size).and_return(2)
      end

      it 'creates a \'green\' environment' do
        expect(green_env).to receive(:create)

        subject.deploy
      end

      it 'scales the green environment to match the blue environment' do
        expect(green_env).to receive(:scale_up).with(2)

        subject.deploy
      end

      it 'deletes the blue environment' do
        expect(blue_env).to receive(:destroy)

        subject.deploy
      end
    end

    context 'only green environment exists' do
      before do
        allow(blue_env).to receive(:exists?).and_return(false)
        allow(green_env).to receive(:exists?).and_return(true)

        allow(green_env).to receive(:size).and_return(6)
      end

      it 'creates a \'blue\' environment' do
        expect(blue_env).to receive(:create)

        subject.deploy
      end

      it 'scales the blue environment to match the green environment' do
        expect(blue_env).to receive(:scale_up).with(6)

        subject.deploy
      end

      it 'deletes the green environment' do
        expect(green_env).to receive(:destroy)

        subject.deploy
      end
    end
  end

  describe '#delete' do
    context 'both blue and green environments exist' do
      before do
        allow(blue_env).to receive(:exists?).and_return(true)
        allow(green_env).to receive(:exists?).and_return(true)
      end

      it 'raises an error because another deployment is in progress' do
        expect { subject.delete }.to raise_error
      end
    end

    context 'only blue environment exists' do
      before do
        allow(blue_env).to receive(:exists?).and_return(true)
        allow(green_env).to receive(:exists?).and_return(false)
      end

      it 'deletes the \'blue\' environment' do
        expect(blue_env).to receive(:destroy)

        subject.delete
      end
    end

    context 'only green environment exists' do
      before do
        allow(blue_env).to receive(:exists?).and_return(false)
        allow(green_env).to receive(:exists?).and_return(true)
      end

      it 'deletes the \'green\' environment' do
        expect(green_env).to receive(:destroy)

        subject.delete
      end
    end
  end
end
