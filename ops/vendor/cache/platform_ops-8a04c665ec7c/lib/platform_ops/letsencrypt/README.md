# Usage
## Get SSL certificates for your domain
  bundle exec thor ssl_cert:new --domain=your_domain_name --hosted-zone=your_hosted_zone_id_for_your_domain_name --email=contact_email_for_letsencrypt_registration --dir=directory_to_save_cerficates_default_current_directory

  \#test_run to execute the command using acme staging environment
  
  bundle exec thor ssl_cert:new --test_run --domain=your_domain_name --hosted-zone=your_hosted_zone_id_for_your_domain_name --email=contact_email_for_letsencrypt_registration --dir=directory_to_save_certificates_default_current_directory

There is rate limit to get the new certificate for each domain in letsencrypt through acme production api. So it is recommended to execute test runs first using acme staging environment to verify the command arguments are correctly configured.

## Convert SSL certificates to escape new line, useful to be inserted into a data bag json file

  bundle exec thor ssl_cert:convert --dir=directory_with_certificate_files

