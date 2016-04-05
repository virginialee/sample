require 'netaddr'

module PlatformOps
  module Networking
    extend self

    # Find an unused cidr block in a network
    # @param network [String] IPV4 CIDR notation of network to search within
    # @param subnets [Array<String>] IPV4 CIDR notation of existing subnets in the network
    # @param bits Optional parameters that can be overridden.
    # @return [String] Available cidr block of 'bits' size within 'subnet', or nil if none were found
    def find_unused_cidr_block(network, subnets, bits=28)
      network_cidr = NetAddr::CIDR.create(network)
      subnet_cidrs = subnets.map { |s| NetAddr::CIDR.create(s) }

      gaps = network_cidr.fill_in(subnet_cidrs, Objectify: true) - subnet_cidrs

      gaps.select { |x| x.bits <= bits }.sort_by { |x| x.bits }.map { |x| x.resize(bits).to_s }.last
    end

    # Returns the public IP address of the current machine
    # Requires the 'dig' command line tool to be installed.
    # @return [String] Your public IPV4 address
    def my_public_ip
      if @my_public_ip
        @my_public_ip
      else
        #Use AWS instance data if available
        ip = `curl -s http://instance-data/latest/meta-data/public-ipv4`.chomp
        ip = nil unless $?.exitstatus == 0

        unless ip
          #Use DNS
          ip = `dig +short +tries=1 -4 myip.opendns.com @resolver1.opendns.com`.chomp
          ip = nil unless $?.exitstatus == 0 #Might be set to an error message if command failed
        end

        unless ip
          #Use 3rd party IP echo service
          ip = `curl -s http://ipecho.net/plain`.chomp
          ip = nil unless $?.exitstatus == 0
        end

        raise 'Could not get the public IP of the current machine' if ip.nil?

        @my_public_ip = ip
      end
    end
  end
end
