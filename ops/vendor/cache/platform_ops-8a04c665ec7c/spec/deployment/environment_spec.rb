require 'aws-sdk-core'
require_relative '../spec_helper'
require_relative '../../lib/platform_ops/deployment/rolling_deployer'

RSpec.describe PlatformOps::Deployment::RollingDeployer do

  let(:ec2_client) {
    instance_double(Aws::EC2::Client)
  }

  let(:auto_scaling_client) {
    instance_double(Aws::AutoScaling::Client, suspend_processes: nil)
  }

  let(:elb_client) {
    instance_double(Aws::ElasticLoadBalancing::Client)
  }

  let(:cloud_watch_client) {
    instance_double(Aws::ElasticLoadBalancing::Client)
  }

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

  let(:name) {
    "#{config[:stack_name]}-autoscaling-blue"
  }

  let(:alarm_prefix) {
    "#{config[:stack_name]}-autoscaling-blue-alarms"
  }

  let(:asg) {
    instance_double(Aws::AutoScaling::Types::AutoScalingGroup, auto_scaling_group_name: name, desired_capacity: 437)
  }

  subject {
    PlatformOps::Deployment::Environment.new(name, alarm_prefix, config)
  }

  before do
    allow(Aws::EC2::Client).to receive(:new).and_return(ec2_client)
    allow(Aws::AutoScaling::Client).to receive(:new).and_return(auto_scaling_client)
    allow(Aws::ElasticLoadBalancing::Client).to receive(:new).and_return(elb_client)
    allow(Aws::ElasticLoadBalancing::Client).to receive(:new).and_return(cloud_watch_client)
  end

  describe '#exists?' do
    it 'returns true if an ASG with the given name exists' do
      allow(subject).to receive(:find_auto_scaling_group).with(name).and_return(asg)

      expect(subject.exists?).to eq(true)
    end

    it 'returns false if no ASG with the given name exists' do
      allow(subject).to receive(:find_auto_scaling_group).with(name).and_return(nil)

      expect(subject.exists?).to eq(false)
    end
  end

  describe '#create' do
    it 'creates & configures a new launch configuration & ASG, and scales it up to minimum size' do
      expect(subject).to receive(:create_unique_launch_configuration_name).and_return('lc_name')
      expect(subject).to receive(:create_launch_configuration)
      expect(subject).to receive(:create_auto_scaling_group)
      expect(subject).to receive(:apply_auto_scaling_configuration)
      expect(subject).to receive(:await_asg_instance_count)

      subject.create
    end

    it 'rolls everything back if anything fails' do
      allow(subject).to receive(:create_unique_launch_configuration_name).and_return('lc_name')
      allow(subject).to receive(:create_launch_configuration)
      allow(subject).to receive(:create_auto_scaling_group).and_raise('NOOOOOO')

      expect(subject).to receive(:destroy).with('lc_name')

      expect { subject.create }.to raise_error('NOOOOOO')
    end
  end

  describe '#scale_up' do
    it 'scales the group to the given size' do
      expect(subject).to receive(:find_auto_scaling_group!).and_return(double(max_size: 10))
      expect(auto_scaling_client).to receive(:set_desired_capacity)
          .with(auto_scaling_group_name: name, desired_capacity: 7)
      expect(subject).to receive(:await_asg_instance_count) do |asg_name, _, _, &block|
        expect(asg_name).to eq(name)
        expect(block.call(6)).to eq(false)
        expect(block.call(7)).to eq(true)
      end

      subject.scale_up(7)
    end

    it 'scales to the maximum ASG size if the given size is too large' do
      expect(subject).to receive(:find_auto_scaling_group!).and_return(double(max_size: 5))
      expect(auto_scaling_client).to receive(:set_desired_capacity)
          .with(auto_scaling_group_name: name, desired_capacity: 5)
      expect(subject).to receive(:await_asg_instance_count) do |asg_name, _, _, &block|
        expect(asg_name).to eq(name)
        expect(block.call(4)).to eq(false)
        expect(block.call(5)).to eq(true)
      end

      subject.scale_up(7)
    end
  end

  describe '#size' do
    it 'gets the size' do
      expect(subject).to receive(:find_auto_scaling_group!).with(name).and_return(asg)

      expect(subject.size).to eq(437)
    end
  end

  describe '#destroy' do
    it 'deletes the ASG if it exists' do
      expect(subject).to receive(:find_auto_scaling_group)
          .with(name)
          .and_return(double(launch_configuration_name: 'lc'))

      expect(auto_scaling_client).to receive(:suspend_processes)

      expect(subject).to receive(:delete_auto_scaling_configuration).with(name, alarm_prefix, config)

      expect(auto_scaling_client).to receive(:update_auto_scaling_group).with(
          auto_scaling_group_name: name,
          min_size: 0,
          max_size: 0,
          desired_capacity: 0)

      expect(subject).to receive(:await_asg_instance_count) do |asg_name, _, _, &block|
        expect(asg_name).to eq(name)
        expect(block.call(1,0,1)).to eq(false)
        expect(block.call(0,1,1)).to eq(false)
        expect(block.call(0,0,0)).to eq(true)
      end

      expect(subject).to receive(:delete_auto_scaling_group).with(name)

      expect(subject).to receive(:delete_launch_configuration).with('lc')

      subject.destroy
    end

    it 'deletes the specified launch configuration' do
      expect(subject).to receive(:find_auto_scaling_group).and_return(nil)
      expect(subject).to receive(:delete_launch_configuration).with('custom_lc_name')

      subject.destroy('custom_lc_name')
    end
  end

  describe '#update' do
    it 'replaces the launch configuration on the ASG' do
      drain_args = {
        auto_scaling_group_name: name,
        min_size: 0,
        max_size: 0,
        desired_capacity: 0
      }

      update_args = {
        auto_scaling_group_name: name,
        min_size: config[:autoscaling_min],
        max_size: config[:autoscaling_max],
        launch_configuration_name: 'new_lc'
      }

      expect(subject).to receive(:find_auto_scaling_group!)
          .with(name)
          .and_return(double(launch_configuration_name: 'old_lc'))

      expect(subject).to receive(:create_unique_launch_configuration_name).and_return('new_lc')

      expect(auto_scaling_client).to receive(:suspend_processes)

      expect(auto_scaling_client).to receive(:update_auto_scaling_group).with(drain_args).ordered
      expect(auto_scaling_client).to receive(:update_auto_scaling_group).with(update_args).ordered

      expect(subject).to receive(:await_asg_instance_count).exactly(2).times

      expect(subject).to receive(:delete_launch_configuration).with('old_lc')
      expect(subject).to receive(:create_launch_configuration).with('new_lc', anything, anything, anything)

      expect(auto_scaling_client).to receive(:resume_processes)

      subject.update
    end
  end
end
