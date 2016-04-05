require 'aws-sdk-core'
require_relative '../spec_helper'
require_relative '../../lib/platform_ops/deployment/utils'

RSpec.describe PlatformOps::Deployment::Utils do

  let(:ec2) {
    instance_double(Aws::EC2::Client)
  }

  let(:auto_scaling) {
    instance_double(Aws::AutoScaling::Client)
  }

  let(:elb) {
    instance_double(Aws::ElasticLoadBalancing::Client)
  }

  subject {
    anon_class = Class.new do
      include PlatformOps::Deployment::Utils

      def initialize(ec2, auto_scaling, elb)
        @ec2 = ec2
        @auto_scaling = auto_scaling
        @elb = elb
      end
    end

    anon_class.new(ec2, auto_scaling, elb)
  }

  describe '#find_auto_scaling_group' do
    it 'finds the auto scaling group' do
      response = {
        auto_scaling_groups: [1]
      }

      expect(auto_scaling).to receive(:describe_auto_scaling_groups).and_return(OpenStruct.new(response))

      expect(subject.find_auto_scaling_group('test')).to eq(1)
    end

    it 'raises an error if there are too many matches' do
      response = {
        auto_scaling_groups: [1, 2]
      }

      expect(auto_scaling).to receive(:describe_auto_scaling_groups).and_return(OpenStruct.new(response))

      expect { subject.find_auto_scaling_group('test') }.to raise_error
    end

    it 'returns nil if there are no matches' do
      response = {
        auto_scaling_groups: []
      }

      expect(auto_scaling).to receive(:describe_auto_scaling_groups).and_return(OpenStruct.new(response))

      expect(subject.find_auto_scaling_group('test')).to be_nil
    end
  end

  describe '#find_auto_scaling_group!' do
    it 'finds the auto scaling group' do
      expect(subject).to receive(:find_auto_scaling_group).and_return(1)

      expect(subject.find_auto_scaling_group!('test')).to eq(1)
    end

    it 'raises an error if there are no matches' do
      expect(subject).to receive(:find_auto_scaling_group).and_return(nil)

      expect { subject.find_auto_scaling_group!('test') }.to raise_error
    end
  end

  describe '#find_security_group' do
    it 'finds the security group' do
      response = {
        security_groups: [1]
      }

      expect(ec2).to receive(:describe_security_groups).and_return(OpenStruct.new(response))

      expect(subject.find_security_group('test')).to eq(1)
    end

    it 'raises an error if there are too many matches' do
      response = {
        security_groups: [1, 2]
      }

      expect(ec2).to receive(:describe_security_groups).and_return(OpenStruct.new(response))

      expect { subject.find_security_group('test') }.to raise_error
    end

    it 'returns nil if there are no matches' do
      response = {
        security_groups: []
      }

      expect(ec2).to receive(:describe_security_groups).and_return(OpenStruct.new(response))

      expect(subject.find_security_group('test')).to be_nil
    end
  end

  describe '#find_security_group!' do
    it 'finds the security group' do
      expect(subject).to receive(:find_security_group).and_return(1)

      expect(subject.find_security_group!('test')).to eq(1)
    end

    it 'raises an error if there are no matches' do
      expect(subject).to receive(:find_security_group).and_return(nil)

      expect { subject.find_security_group!('test') }.to raise_error
    end
  end

  describe '#find_subnets' do
    it 'finds the subnets' do
      subnets = [
        OpenStruct.new(tags: [OpenStruct.new(key: 'Name', value: 'test-subnet')]),
        OpenStruct.new(tags: [OpenStruct.new(key: 'Name', value: 'random-subnet')])
      ]

      response = {
        subnets: subnets
      }

      expect(ec2).to receive(:describe_subnets).and_return(OpenStruct.new(response))

      expect(subject.find_subnets('vpc_id', 'test')).to eq([subnets[0]])
    end

    it 'returns [] if there are no matches' do
      subnets = [
        OpenStruct.new(tags: [OpenStruct.new(key: 'Name', value: 'random-subnet')])
      ]

      response = {
        subnets: subnets
      }

      expect(ec2).to receive(:describe_subnets).and_return(OpenStruct.new(response))

      expect(subject.find_subnets('vpc_id', 'test')).to eq([])
    end
  end

  describe '#find_subnets!' do
    it 'finds the subnets' do
      expect(subject).to receive(:find_subnets).and_return([1])

      expect(subject.find_subnets!('vpc_id', 'test')).to eq([1])
    end

    it 'raises an error if there are no matches' do
      expect(subject).to receive(:find_subnets).and_return([])

      expect { subject.find_subnets!('vpc_id', 'test') }.to raise_error
    end
  end

  describe '#find_vpc' do
    it 'finds the vpc' do
      response = {
        vpcs: [1]
      }

      expect(ec2).to receive(:describe_vpcs).and_return(OpenStruct.new(response))

      expect(subject.find_vpc('test')).to eq(1)
    end

    it 'raises an error if there are too many matches' do
      response = {
        vpcs: [1, 2]
      }

      expect(ec2).to receive(:describe_vpcs).and_return(OpenStruct.new(response))

      expect { subject.find_vpc('test') }.to raise_error

    end

    it 'returns nil if there are no matches' do
      response = {
        vpcs: []
      }

      expect(ec2).to receive(:describe_vpcs).and_return(OpenStruct.new(response))

      expect(subject.find_vpc('test')).to eq(nil)
    end
  end

  describe '#find_vpc!' do
    it 'finds the vpc' do
      expect(subject).to receive(:find_vpc).and_return(1)

      expect(subject.find_vpc!('test')).to eq(1)
    end

    it 'raises an error if there are no matches' do
      expect(subject).to receive(:find_vpc).and_return(nil)

      expect { subject.find_vpc!('test') }.to raise_error
    end
  end

  describe '#await_asg_instance_count' do
    it 'should repeatedly query the instances in the asg and the elb until the block returns true' do
      elb_result1 = OpenStruct.new(instance_states: [
          OpenStruct.new(instance_id: '1', state: 'OutOfService'),
          OpenStruct.new(instance_id: '2', state: 'OutOfService')
        ])
      elb_result2 = OpenStruct.new(instance_states: [
          OpenStruct.new(instance_id: '1', state: 'OutOfService'),
          OpenStruct.new(instance_id: '2', state: 'InService')
        ])
      elb_result3 = OpenStruct.new(instance_states: [
          OpenStruct.new(instance_id: '1', state: 'InService'),
          OpenStruct.new(instance_id: '2', state: 'InService')
        ])

      asg_result1 = OpenStruct.new(instances: [
          OpenStruct.new(instance_id: '1', health_status: 'Unhealthy', lifecycle_state: 'OutOfService'),
          OpenStruct.new(instance_id: '2', health_status: 'Unhealthy', lifecycle_state: 'OutOfService')
        ])
      asg_result2 = OpenStruct.new(instances: [
          OpenStruct.new(instance_id: '1', health_status: 'Healthy', lifecycle_state: 'InService'),
          OpenStruct.new(instance_id: '2', health_status: 'Healthy', lifecycle_state: 'InService')
        ])
      asg_result3 = OpenStruct.new(instances: [
          OpenStruct.new(instance_id: '1', health_status: 'Healthy', lifecycle_state: 'InService'),
          OpenStruct.new(instance_id: '2', health_status: 'Healthy', lifecycle_state: 'InService')
        ])

      expect(subject).to receive(:find_auto_scaling_group!)
          .exactly(3)
          .times
          .and_return(asg_result1, asg_result2, asg_result3)

      expect(elb).to receive(:describe_instance_health)
          .exactly(3)
          .times
          .and_return(elb_result1, elb_result2, elb_result3)

      subject.await_asg_instance_count('test-asg', 'test-elb', 4, 0.1) do |in_service, out_of_service, total|
        in_service >= 2
      end
    end
  end

  describe '#only_these_asgs!' do
    it 'should raise an error if there are non-whitelisted ASGs in the load balancer' do
      response = OpenStruct.new(auto_scaling_groups: [
          OpenStruct.new(auto_scaling_group_name: 'relevant1', load_balancer_names: ['my-lb']),
          OpenStruct.new(auto_scaling_group_name: 'irrelevant', load_balancer_names: ['other-lb']),
          OpenStruct.new(auto_scaling_group_name: 'relevant2', load_balancer_names: ['my-lb', 'other-lb'])
        ])

      expect(auto_scaling).to receive(:describe_auto_scaling_groups).twice.and_return(response)

      expect { subject.only_these_asgs!('my-lb', ['relevant1']) }.to raise_error
      expect { subject.only_these_asgs!('my-lb', ['relevant1', 'relevant2']) }.not_to raise_error
    end
  end
end
