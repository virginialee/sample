require 'openssl'
require 'acme/client'
require_relative 'dns_provision'

class SslCertIssuer
  include DnsProvision

  PRODUCTION_ENDPOINT = 'https://acme-v01.api.letsencrypt.org/'
  STAGING_ENDPOINT = 'https://acme-staging.api.letsencrypt.org'

  def initialize(test_run = false)
    @test_run = test_run
  end

  def issue_cert(domain_name, hosted_zone_name, email, file_dir)
    puts 'start to request ssl certificates in test run' if @test_run
    puts "requesting ssl certificates for domain: #{domain_name}, hosted_zone_name: #{hosted_zone_name}"
    puts "with contact email: #{email}, saved ssl certificates in #{file_dir}"

    challenge = request_challenge(domain_name, email)
    puts '================'
    puts challenge.record_content
    puts '================'
    create_update_record_set(domain_name, hosted_zone_name, challenge.record_content)
    sleep 60
    verify_challenge(challenge)
    certificate = request_certificate(domain_name)
    generate_certificate_files(certificate, file_dir)
  end

  def client
    endpoint = @test_run ? STAGING_ENDPOINT : PRODUCTION_ENDPOINT
    @client ||= Acme::Client.new(private_key: OpenSSL::PKey::RSA.new(4096), endpoint: endpoint)
  end
  private

  def request_challenge(domain_name, email)
    registration = client.register(contact: email)
    registration.agree_terms
    authorization = client.authorize(domain: domain_name)
    authorization.dns01
  end

  def request_certificate(domain_name)
    csr = Acme::Client::CertificateRequest.new(names: [domain_name])
    client.new_certificate(csr)
  end

  def generate_certificate_files(certificate, file_dir)
    File.write(File.join(file_dir, 'privkey.pem'), certificate.request.private_key.to_pem)
    File.write(File.join(file_dir, 'cert.pem'), certificate.to_pem)
    File.write(File.join(file_dir, 'chain.pem'), certificate.chain_to_pem)
    File.write(File.join(file_dir, 'fullchain.pem'), certificate.fullchain_to_pem)
  end

  def verify_challenge(challenge)
    challenge.request_verification
    puts 'sent challenge verification request'
    puts "verification status: #{challenge.verify_status}"
    timeout = 0
    while (!valid_status?(challenge)) && timeout < 3
      # puts challenge.inspect
      puts "verification status: #{challenge.verify_status}..."
      sleep 1
      timeout += 1
    end
    verification_result = challenge.verify_status
    unless valid_status?(challenge)
      raise StandardError.new("challenge verification failed with status: #{verification_result}")
    end
    puts 'challenge verification passed!'
  end

  def valid_status?(challenge)
    'valid' == challenge.verify_status
  end
end