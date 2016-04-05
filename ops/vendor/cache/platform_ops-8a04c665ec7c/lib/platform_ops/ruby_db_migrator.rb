require_relative 'shell_helpers'

module PlatformOps
  class RubyDbMigrator
    def initialize(paths, config, secret)
      @app_source_path = File.expand_path(paths[:app_source])

      @host = config[:host]
      @port = config[:port] || 5432
      @database = config[:database]
      db_data_bag_item = secret.data_bag_item(config[:data_bag_name], config[:data_bag_item_name])

      @migration_user = db_data_bag_item['master_username']
      @migration_password = db_data_bag_item['master_password']
    end

    def run(environment)
      set_env_cmd = %W(
          RACK_ENV=#{environment}
          DATABASE_NAME=#{@database}
          PG_HOST=#{@host}:#{@port}
          PG_USER=#{@migration_user}
          PG_PASSWORD=#{@migration_password}
      ).join(' ')

      bundle_cmd = "(bundle check || bundle install) && #{set_env_cmd} bundle exec rake db:migrate[#{environment},up]"

      full_cmd = "sudo -H -u $USER bash -l -c \"#{bundle_cmd}\""

      PlatformOps::ShellHelpers.execute(full_cmd, dir: @app_source_path, quiet: true, fail_hard: true)
    end
  end
end
