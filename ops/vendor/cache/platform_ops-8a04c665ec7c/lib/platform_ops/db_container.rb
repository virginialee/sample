require 'open3'
require 'pg'
require_relative 'postgres_db_initializer'

module PlatformOps
  class DbContainer
    def initialize(config)
      @host = config[:host]
      @app_database = config[:app_database]
      @master_username = config[:master_username] || 'postgres'
      @master_password = config[:master_password] || 'mysecretpassword'
      @app_username = config[:app_username] || 'app'
      @app_password = config[:app_password] || 'mysecretpassword'
      @container_name = config[:container_name] || 'postgres-unit-test'
      @poll_attempts = config[:poll_attempts] || 60
      @sudo = if sudo_docker? then 'sudo ' else '' end
      @db_init = PlatformOps::PostgresDbInitializer.new(@host, @master_username, @master_password)
    end

    def up
      if container_exists?
        remove_container
      end

      run_container
      poll_db_running
      init_db

      puts "OK. container #{@container_name} is up"
    end

    def destroy
      if container_exists?
        remove_container
        puts "OK. container #{@container_name} is destroyed"
      else
        puts "Container #{@container_name} is not running. No action required."
      end
    end

    private

    def sudo_docker?
      !shell_out_silent("docker ps")
    end

    def container_exists?
      shell_out_silent("#{@sudo}docker inspect #{@container_name}")
    end

    def run_container
      cmd = "#{@sudo}docker run --name #{@container_name}"
      cmd << " -e POSTGRES_USER=#{@master_username}"
      cmd << " -e POSTGRES_PASSWORD=#{@master_password}"
      cmd << " -p 5432:5432 -d postgres:9.4"
      raise 'failed to run docker' unless shell_out_silent(cmd)
      puts "Running container #{@container_name}"
    end

    def remove_container
      raise 'failed to stop docker' unless shell_out_silent("#{@sudo}docker stop #{@container_name}")
      raise 'failed to remove docker' unless shell_out_silent("#{@sudo}docker rm -v #{@container_name}")
      puts "Removed container #{@container_name}"
    end

    def poll_db_running
      @db_init.poll_running(@poll_attempts)
    end

    def init_db
      @db_init.create_database(@app_database)
      @db_init.create_user(@app_username, @app_password)
      @db_init.grant_full_privileges(@app_database, @app_username)
    end

    def shell_out_silent(cmd)
      Open3.popen3(cmd) { |i,o,e,t| t.value }.success?
    end
  end
end
