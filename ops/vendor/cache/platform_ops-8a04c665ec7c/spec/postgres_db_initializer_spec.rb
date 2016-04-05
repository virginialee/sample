require_relative 'spec_helper'
require_relative '../lib/platform_ops/postgres_db_initializer'

RSpec.describe PlatformOps::PostgresDbInitializer do

  subject { PlatformOps::PostgresDbInitializer.new('localhost', 'masteruser', 'masterpassword') }

  let(:database) { 'test_db' }
  let(:mock_master_db_connection) { double('master_db_connection') }
  let(:mock_app_db_connection) { double('app_db_connection') }

  before(:each) do
    allow(subject).to receive(:create_connection).with('postgres').and_return(mock_master_db_connection)
    allow(subject).to receive(:create_connection).with(database).and_return(mock_app_db_connection)

    allow(mock_app_db_connection).to receive(:close)
    allow(mock_master_db_connection).to receive(:close)
  end

  describe 'create_database' do
    it 'should create the database if it is new' do
      allow(mock_master_db_connection).to receive(:exec_params)
                                     .with('SELECT * FROM pg_database where datname = $1', anything)
                                     .and_return(double(num_tuples: 0))

      expect(mock_master_db_connection).to receive(:query)
                                    .with("CREATE DATABASE #{database}")

      subject.create_database(database)
    end

    it 'should do nothing if the database already exists' do
      allow(mock_master_db_connection).to receive(:exec_params)
                                    .with('SELECT * FROM pg_database where datname = $1', anything)
                                    .and_return(double(num_tuples: 1))

      expect(mock_master_db_connection).not_to receive(:query)

      subject.create_database(database)
    end
  end

  describe 'create_user' do
    it 'should create the user if they are new' do
      username = 'test_user'
      password = 'test_pass'

      allow(mock_master_db_connection).to receive(:exec_params)
                                    .with('SELECT * FROM pg_user WHERE usename=$1', anything)
                                    .and_return(double(num_tuples: 0))

      expect(mock_master_db_connection).to receive(:query)
                                     .with("CREATE USER \"#{username}\" WITH NOCREATEDB NOCREATEROLE LOGIN NOREPLICATION NOSUPERUSER PASSWORD '#{password}'")

      subject.create_user(username, password)
    end

    it 'update the users password if they already exist' do
      username = 'test_user'
      password = 'test_pass'

      allow(mock_master_db_connection).to receive(:exec_params)
                                    .with('SELECT * FROM pg_user WHERE usename=$1', anything)
                                    .and_return(double(num_tuples: 1))

      expect(mock_master_db_connection).to receive(:query)
                                               .with("ALTER USER \"#{username}\" WITH PASSWORD '#{password}'")


      subject.create_user(username, password)
    end
  end
end
