require_relative 'spec_helper'
require_relative '../lib/platform_ops/networking'
require 'netaddr'

RSpec.describe PlatformOps::Networking do
  describe 'my_public_ip' do
    it 'should return the current machine\'s public ip' do
      ip = PlatformOps::Networking.my_public_ip

      expect(ip).to be_a(String)
      expect(ip.empty?).to eq false
      expect { NetAddr::CIDRv4.create("#{ip}/32") }.not_to raise_error
    end
  end

  describe 'find_unused_cidr_block' do
    it 'should return nil if there is no available cidr block of the requested size' do
      result = PlatformOps::Networking.find_unused_cidr_block('192.168.0.0/31', %w(192.168.0.0/32 192.168.0.1/32))

      expect(result).to be_nil
    end

    it 'should return an unoccupied cidr block if one exists' do
      result = PlatformOps::Networking.find_unused_cidr_block('192.168.0.0/31', %w(192.168.0.0/32), 32)

      expect(result).to be_a(String)
      expect(result).to eq('192.168.0.1/32')
    end

    it 'should return the smallest unoccupied cidr block if multiple exist' do
      <<-DOC
      192.168.0.0 (free)
      192.168.0.1 (free)
      192.168.0.2 (free)
      192.168.0.3 (free)
      192.168.0.4 (occupied)
      192.168.0.5 (occupied)
      192.168.0.6 (free) ***
      192.168.0.7 (free) ***
      DOC

      result = PlatformOps::Networking.find_unused_cidr_block('192.168.0.0/29', %w(192.168.0.4/31), 31)
      expect(result).to eq('192.168.0.6/31')
    end
  end
end
