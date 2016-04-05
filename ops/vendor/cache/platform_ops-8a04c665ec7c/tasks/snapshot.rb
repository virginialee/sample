require_relative '../lib/platform_ops/snapshot_cleaner'

namespace :platform_ops do
  namespace :snapshot do

    desc 'Cleanup snapshots'
    task :clean, [:region] do |_t, args|
      cleaner = PlatformOps::SnapshotCleaner.new(region: args[:region])
      cleaner.clean_unused_snapshots
    end

  end
end
