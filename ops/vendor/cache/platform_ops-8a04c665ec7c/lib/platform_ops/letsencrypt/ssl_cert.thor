require './ssl_cert_issuer'
require './ssl_cert_converter'

class SslCert < Thor
  desc 'new', 'get new ssl certificates for domain'
  method_option :domain, aliases:'-d', required: true
  method_option :hosted_zone, aliases: '-h', required: true
  method_option :email, aliases: '-e', required: true
  method_option :dir, aliases: '-f', default: '.', required: true
  method_option :test_run, aliases: '-t', type: :boolean
  def new_ssl_cert
    # domain_name = 'lifei.reporting.dev.myob.com'
    # hosted_zone_id = 'reporting.dev.myob.com.'
    # email = 'mailto:lifei.zhou@myob.com'
    domain_name = options[:domain]
    hosted_zone_name = options[:hosted_zone]
    email = "mailto:#{options[:email]}"
    file_dir = options[:dir]
    test_run = options[:test_run]
    SslCertIssuer.new(test_run).issue_cert(domain_name, hosted_zone_name, email, file_dir)
  end

  desc 'convert', 'convert file contents to be a json format value'
  method_option :dir, aliases: '-f', default: '.', required: true
  def convert_file_content
    SslCertConverter.new.convert_files(options[:dir])
  end
end
