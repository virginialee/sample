require_relative 'spec_helper'
require_relative '../lib/platform_ops/chef_secret'

RSpec.describe PlatformOps::ChefSecret do

  subject {
    PlatformOps::ChefSecret.new(
        bucket_name: 'bucket',
        bucket_key: 'key',
        bucket_region: 'us-west-2',
        data_bag_path: './data_bags'
    )
  }

  before(:each){
    expect_any_instance_of(Aws::S3::Client)
        .to receive(:get_object)
        .with(bucket: 'bucket', key: 'key')
        .and_return(double(body: StringIO.new('the secret!')))
  }

  describe '#data_bag_item' do
    it 'loads the requested data bag item' do
      expect(File)
          .to receive(:read)
          .with('./data_bags/bag/item.json')
          .and_return(JSON.generate({ success: true }))

      result = subject.data_bag_item('bag', 'item')

      expect(result).to be_a(Chef::EncryptedDataBagItem)
      expect(result.instance_exec { @secret }).to eq('the secret!')
      expect(result.instance_exec { @enc_hash }).to eq({'success' => true})
    end
  end

  describe '#with_secret_file' do
    it 'yields a path to the secret file' do
      subject.with_secret_file { |path| expect(File.exists?(path)).to eq(true) }
    end

    it 'yields a secret file with the correct content' do
      subject.with_secret_file { |path| expect(File.read(path)).to eq('the secret!') }
    end

    it 'removes the secret file when the block exits' do
      path = subject.with_secret_file { |secret_path| path = secret_path }
      expect(File.exists?(path)).to eq(false)
    end
  end
end
