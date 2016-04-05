require 'openssl'

class PlatformOps::Certificate

  def initialize(cert)
    @cert = OpenSSL::X509::Certificate.new(cert)
  end

  def expires_within?(days = 21)
    cert_expiry_date = @cert.not_after.to_date
    Date.today >= cert_expiry_date - days
  end

end