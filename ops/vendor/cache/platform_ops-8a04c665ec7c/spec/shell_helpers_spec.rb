require_relative 'spec_helper'
require_relative '../lib/platform_ops/shell_helpers'

RSpec.describe PlatformOps::ShellHelpers do

  subject {
    Object.new.extend(PlatformOps::ShellHelpers)
  }

  describe '#execute' do
    it 'calls out to the kernel shell' do
      expect(Kernel).to receive(:system)

      subject.execute('echo')
    end

    it 'changes directory if a directory is provided' do
      allow(Kernel).to receive(:system)
      expect(Dir).to receive(:chdir).with('..')

      subject.execute('echo', dir: '..')
    end
  end

  describe '::execute' do
    it 'calls out to the kernel shell' do
      expect(Kernel).to receive(:system)

      PlatformOps::ShellHelpers.execute('echo')
    end

    it 'changes directory if a directory is provided' do
      allow(Kernel).to receive(:system)
      expect(Dir).to receive(:chdir).with('..')

      PlatformOps::ShellHelpers.execute('echo', dir: '..')
    end
  end

  describe 'module' do
    it 'includes the logging module' do
      expect(subject.respond_to?(:logger)).to eq(true)
    end
  end
end
