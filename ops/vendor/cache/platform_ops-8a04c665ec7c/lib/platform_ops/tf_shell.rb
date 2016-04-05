require 'openssl'
require 'base64'
require 'digest/sha2'
require 'fileutils'
require 'json'
require_relative 'logging'

module PlatformOps
  class TfShell
    include PlatformOps::Logging

    TF_STATE_FILE = 'terraform.tfstate'
    TF_SHELL_CONFIG_FILE = 'tfshell.config'
    TF_SHELL_ENCRYPTED_STATE_FILE = 'encrypted_tfstate'

    # Shell exit codes for error conditions
    EXITCODE_MISSING_CONFIG = 1
    EXITCODE_REMOTE_STATE_PRESENT = 2

    def initialize(args)
      @args = args
      @config = read_config

      logger.formatter = proc do |severity, datetime, progname, msg|
        "[tfshell] #{msg}\n"
      end

      ensure_remote_state_disabled
    end

    def run
      begin
        original_digest = nil
        updated_digest = nil

        if File.exists? TF_SHELL_ENCRYPTED_STATE_FILE
          state_data = convert_file(TF_SHELL_ENCRYPTED_STATE_FILE, TF_STATE_FILE, @config['secret_file']) do |encrypted_data, key|
            decrypt_data(encrypted_data, key, @config['iv'])
          end
          original_digest = digest_data(state_data)
        end

        logger.info "$ terraform #{@args.join(' ')}"
        Kernel.system('terraform', *@args)
        tf_exit_code = $?.exitstatus

        if File.exists? TF_STATE_FILE
          updated_digest = digest_file(TF_STATE_FILE)
        end

        if original_digest != updated_digest
          if File.exists? TF_STATE_FILE
            logger.info 'Terraform state changed. Re-encrypting updated state'
            convert_file(TF_STATE_FILE, TF_SHELL_ENCRYPTED_STATE_FILE, @config['secret_file']) do |state_data, key|
              encrypt_data(state_data, key, @config['iv'])
            end
            logger.info "Encrypted #{TF_STATE_FILE} to #{TF_SHELL_ENCRYPTED_STATE_FILE}"
          end
        else
          logger.info 'No change to terraform state'
        end

        tf_exit_code

      ensure
        cleanup
      end
    end

    private

    def read_config
      unless File.exists? TF_SHELL_CONFIG_FILE
        puts "ERROR: Cannot find #{TF_SHELL_CONFIG_FILE} in #{FileUtils.pwd}"
        puts <<-BANNER

USAGE:
    Tfshell wraps the actual terraform command, but added the abilities to
    decrypt the terraform state file before the terraform call and encrypt
    the state file after the terraform call.

    You can check in the encrypted state file #{TF_SHELL_ENCRYPTED_STATE_FILE} into source
    control so it can be shared among the team.

    Tfshell will try its best to remove the unencrypted state file
    #{TF_STATE_FILE}. But we suggest adding both #{TF_STATE_FILE} and
    #{TF_STATE_FILE}.backup to .gitignore for maximum safety.

    To use tfshell, you just run `bundle exec tfshell` following the normal
    terraform arguments. For example, `bundle exec tfshell plan --module-depth=1`.

    In order to use tfshell, you need to have a #{TF_SHELL_CONFIG_FILE} config file
    in the current directory. The config file should be JSON formatted with the keys:

      secret_file: The path to the secret file used for encryption/decryption

      iv: The initialization vector for encryption/decryption.
          You can generate a random iv by running `openssl rand -base64 16`

      keep_state_file: Set this to true if you won't to leave the unencrypted
                       state file in the directory, if you are sure it will not
                       be checked in to source control. This key is optional.

        BANNER
        exit EXITCODE_MISSING_CONFIG
      end

      JSON.parse(File.read(TF_SHELL_CONFIG_FILE))
    end

    def ensure_remote_state_disabled
      if File.exists? File.join('.terraform', TF_STATE_FILE)
        puts 'ERROR: Tfshell does not work with terraform remote state yet. Please turn off remote state first.'
        exit EXITCODE_REMOTE_STATE_PRESENT
      end
    end

    def cleanup
      if File.exists? TF_STATE_FILE

        unless @config['keep_state_file']

          if File.exists? TF_SHELL_ENCRYPTED_STATE_FILE # Be polite, only delete state file if encrypted one exists!
            FileUtils.rm_f TF_STATE_FILE
          end

          if File.exists? TF_STATE_FILE
            logger.warn "#{TF_STATE_FILE} remains in the directory. Please make sure it is not checked into source control"
          end

        end
      end
    end

    def convert_file(source_file, target_file, secret_file)
      source_data = File.read(File.expand_path(source_file))
      key = File.read(File.expand_path(secret_file))
      target_data = yield(source_data, key)
      File.write(File.expand_path(target_file), target_data)
      target_data
    end

    def decrypt_data(encrypted_data, key, iv)
      decryptor = OpenSSL::Cipher.new('aes-256-cbc')
      decryptor.decrypt
      # We must set key before iv: https://bugs.ruby-lang.org/issues/8221
      decryptor.key = OpenSSL::Digest::SHA256.digest(key)
      decryptor.iv = Base64.decode64(iv)
      plain_data = decryptor.update(Base64.decode64(encrypted_data))
      plain_data << decryptor.final
    end

    def encrypt_data(plain_data, key, iv)
      encryptor = OpenSSL::Cipher.new('aes-256-cbc')
      encryptor.encrypt
      # We must set key before iv: https://bugs.ruby-lang.org/issues/8221
      encryptor.key = OpenSSL::Digest::SHA256.digest(key)
      encryptor.iv = Base64.decode64(iv)
      encrypted_data = encryptor.update(plain_data)
      encrypted_data << encryptor.final
      Base64.encode64(encrypted_data)
    end

    def digest_file(file)
      digest_data(File.read(File.expand_path(file)))
    end

    def digest_data(data)
      OpenSSL::Digest::SHA256.hexdigest(data)
    end

  end
end
