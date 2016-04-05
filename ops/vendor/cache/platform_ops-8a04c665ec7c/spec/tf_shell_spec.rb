require_relative 'spec_helper'
require_relative '../lib/platform_ops/tf_shell'

RSpec.describe PlatformOps::TfShell do

  it 'should ensure configuration file is present' do
    tfshell_test_env do
      begin
          PlatformOps::TfShell.new({})
      rescue SystemExit => se
        expect(se.status).to eq(PlatformOps::TfShell::EXITCODE_MISSING_CONFIG)
      end
    end
  end

  it 'should ensure remote state is disabled when instantiated' do
    tfshell_test_env do
      begin
        create_remote_state_fixture
        PlatformOps::TfShell.new({})
      rescue SystemExit => se
        expect(se.status).to eq(PlatformOps::TfShell::EXITCODE_REMOTE_STATE_PRESENT)
      ensure
        cleanup_remote_state_fixtures
      end
    end
  end

  it 'should encrypt terraform state file' do
    tfshell_test_env do
      iv = new_initialization_vector
      PlatformOps::TfShell.new('plan')
      # todo
    end
  end

end

def tfshell_test_env &block
  Dir.chdir("spec/fixtures/files/tfshell-env") do
    yield block
  end
end

def terraform_state_file
  File.join('.terraform', PlatformOps::TfShell::TF_STATE_FILE)
end

def create_remote_state_fixture
  FileUtils.mkdir(".terraform")
  FileUtils.touch("#{terraform_state_file}")
end

def cleanup_remote_state_fixtures
  FileUtils.rm("#{terraform_state_file}")
  FileUtils.rmdir(".terraform")
end

def new_initialization_vector
  `openssl rand -base64 16`.chomp
end
