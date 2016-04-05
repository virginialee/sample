require_relative 'spec_helper'
require_relative '../lib/platform_ops/certificate'
require 'openssl'

RSpec.describe PlatformOps::Certificate do

  describe 'expires_within?' do

    it 'returns true when certificate will expire within the days specified' do
      x509 = instance_double(OpenSSL::X509::Certificate,
                             not_after: OpenStruct.new(to_date: Date.today))

      expect(OpenSSL::X509::Certificate).to receive(:new).with('test').and_return(x509)
      certificate = PlatformOps::Certificate.new('test')

      expect(certificate.expires_within?(5)).to eq(true)
    end

    it 'returns false when certificate wont expire within the days specified' do
      x509 = instance_double(OpenSSL::X509::Certificate,
                             not_after: OpenStruct.new(to_date: Date.today + 10))

      expect(OpenSSL::X509::Certificate).to receive(:new).with('test').and_return(x509)
      certificate = PlatformOps::Certificate.new('test')

      expect(certificate.expires_within?(5)).to eq(false)
    end
  end
end
