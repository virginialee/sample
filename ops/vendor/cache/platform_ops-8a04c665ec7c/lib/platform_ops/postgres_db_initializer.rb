require_relative 'logging'
require_relative 'utils'
require 'pg'

module PlatformOps
  class PostgresDbInitializer
    include PlatformOps::Logging

    def initialize(host, master_username, master_password = nil, port = 5432)
      @host = host
      @port = port
      @username = master_username
      @password = master_password
      @master_database = 'postgres'
    end

    def poll_running(attempts = 60)
      PlatformOps::Utils.poll(1, attempts) do
        puts "Try connecting to #{@host} db on port #{@port}"
        begin
          conn = PG::Connection.new(
            host: @host,
            port: @port,
            user: @username,
            password: @password,
            dbname: @master_database
          ).close
          true
        rescue PG::ConnectionBad
          false
        end
      end
    end

    def create_database(db_name)
      db_create(db_name) unless db_exists?(db_name)
    end

    def create_user(username, password)
      if user_exists?(username)
        set_password(username, password)
      else
        user_create(username, password)
      end
    end

    def grant_full_privileges(db_name, username, options={})
      options[:schema] ||= 'public'

      logger.info "GRANT full table, function and sequence privileges in schema #{options[:schema]} to #{username}"
      db_execute(db_name) { |conn|
        conn.query("GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA #{options[:schema]} TO #{username}")
        conn.query("GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA #{options[:schema]} TO #{username}")
        conn.query("GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA #{options[:schema]} TO #{username}")

        conn.query("ALTER DEFAULT PRIVILEGES IN SCHEMA #{options[:schema]} GRANT ALL PRIVILEGES ON TABLES TO #{username}")
        conn.query("ALTER DEFAULT PRIVILEGES IN SCHEMA #{options[:schema]} GRANT ALL PRIVILEGES ON SEQUENCES TO #{username}")
        conn.query("ALTER DEFAULT PRIVILEGES IN SCHEMA #{options[:schema]} GRANT ALL PRIVILEGES ON FUNCTIONS TO #{username}")
      }
    end

    def user_exists?(username)
      db_execute(@master_database) { |conn|
        conn.exec_params('SELECT * FROM pg_user WHERE usename=$1', [username]).num_tuples != 0
      }
    end

    def init_db_for_app(db_name, app_username, app_password)
      create_database(db_name)
      create_user(app_username, app_password)
      grant_full_privileges(db_name, app_username)
    end

    private

    def user_create(username, password)
      logger.info "Creating DB User #{username}"
      db_execute(@master_database) { |conn|
        conn.query("CREATE USER \"#{username}\" WITH NOCREATEDB NOCREATEROLE LOGIN NOREPLICATION NOSUPERUSER PASSWORD '#{password}'")
      }
    end

    def set_password(username, password)
      logger.info "Resetting password for #{username}"
      db_execute(@master_database) { |conn|
        conn.query("ALTER USER \"#{username}\" WITH PASSWORD '#{password}'")
      }
    end

    def db_create(database)
      logger.info "Creating DB #{database}"
      db_execute(@master_database) { |conn|
        conn.query("CREATE DATABASE #{database}")
      }
    end

    def db_exists?(database)
      db_execute(@master_database) { |conn|
        conn.exec_params('SELECT * FROM pg_database where datname = $1', [database]).num_tuples != 0
      }
    end

    def db_execute(db_name, &block)
      begin
        conn = create_connection(db_name)
        block.call(conn)
      ensure
        conn.close rescue nil
      end
    end

    def create_connection(db_name)
      PG::Connection.new(
          host: @host,
          port: @port,
          user: @username,
          password: @password,
          dbname: db_name,
      )
    end
  end
end
