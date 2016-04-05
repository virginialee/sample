require_relative 'spec_helper'
require_relative '../lib/platform_ops/utils'

RSpec.describe PlatformOps::Utils do

  subject { PlatformOps::Utils }

  describe 'aws_client_options' do

    describe 'retry_limit' do
      it 'should have retry_limit specified it not provided' do
        expect(subject.aws_client_options({})).to have_key(:retry_limit)
      end

      it 'should override retry_limit if specified' do
        expect(subject.aws_client_options(retry_limit: 10)).to include(retry_limit: 10)
      end
    end

    describe 'accepted keys' do
      it 'should accept region' do
        expect(subject.aws_client_options(region: 'ap-southeast-2')).to have_key(:region)
      end

      it 'should filter out unknown keys' do
        expect(subject.aws_client_options(blah: 'destroy')).not_to have_key(:blah)
        expect(subject.aws_client_options(assume_role_credentials: nil)).not_to have_key(:assume_role_credentials)
      end
    end

    describe 'credentials' do
      it 'should not include credentials key if not specified' do
        expect(subject.aws_client_options({})).not_to have_key(:credentials)
      end

      describe 'assume role' do
        it 'should create credentials' do
          expect(Aws::AssumeRoleCredentials).to receive(:new)
          expect(subject.aws_client_options(assume_role_credentials: {
            role_session_name: 'blah'
          })).to have_key(:credentials)
        end

        it 'should not modify config in-place' do
          expect(Aws::AssumeRoleCredentials).to receive(:new)
          config = {
            role_arn: 'role_arn',
            role_session_name: 'role_session_name',
            region: 'region'
          }
          config_passin = config.clone
          subject.aws_client_options(assume_role_credentials: config_passin)
          expect(config_passin).to eql(config)
        end

        it 'should append random string to session name' do
          expect(SecureRandom).to receive(:hex).and_return('1afhgsu7')
          expect(Aws::AssumeRoleCredentials).to receive(:new).with(
            hash_including(
              role_session_name: 'session-1afhgsu7'
            )
          )
          subject.aws_client_options(
            assume_role_credentials: {
              role_session_name: 'session-<%=random_string%>'
            }
          )
        end
      end
    end
  end
end
