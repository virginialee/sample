require_relative 'logging'
require_relative 'networking'
require_relative 'jump_box/jump_box_creator'
require_relative 'jump_box/jump_box_destroyer'

module PlatformOps
  class JumpBox
    include PlatformOps::Logging
    include PlatformOps::JumpBoxCreator
    include PlatformOps::JumpBoxDestroyer

    #Shared props

    attr_reader :aws_client_options
    attr_reader :identifier
    attr_reader :vpc_id

    #Creation props

    attr_reader :ssh_public_key_path
    attr_reader :ssh_private_key_path
    attr_reader :ssh_poll_private_ip
    attr_reader :ami_id
    attr_reader :ssh_user
    attr_reader :ingress_cidrs
    attr_reader :security_group_connections
    attr_reader :eip_allocation_id
    attr_reader :instance_type
    attr_reader :cidr

    # Constructs the handler
    # @param [Hash] config Configuration options
    # @option config [String] :vpc_id ID of the target AWS VPC
    # @option config [String] :identifier ('random-string') unique string that identifies the jump box
    # @note The config hash also accepts standard AWS client options
    def initialize(config)
      PlatformOps::Utils.validated_config config, %i(vpc_id)
      @aws_client_options = PlatformOps::Utils.aws_client_options(config)

      @vpc_id = config[:vpc_id]
      @identifier = config[:identifier] || create_random_identifier
      @environment = config[:environment] || 'not specified'
    end

    # Creates the jump box in AWS
    # @param [Hash] config Configuration options.
    # @option config [String] :ami_id ID of AMI to use for jump box instance
    # @option config [String] :ssh_user ssh user to use when connecting to the jump box instance
    # @option config [Array<String>] ([]) :ingress_cidrs cidr blocks to authorise ssh access to in addition to the current machine's public IP
    # @option config [String] :ssh_public_key ('~/.ssh/id_rsa.pub') location of public key to add to jump box instance
    # @option config [String] :ssh_private_key ('~/.ssh/id_rsa') location of private key to use when connecting to jump box instance
    # @option config [Boolean] :ssh_poll_private_ip (false) when true, the private IP of the jump box instance is used to check SSH connectivity instead of the public IP
    # @option config [Array<Hash>] :security_group_connections ([]) array of hashes with :security_group_id and :port keys
    # @option config [String] :eip_allocation_id (nil) Elastic IP Address to assosciate with jump box instance
    # @option config [String] :instance_type (c4.large) instance_type to use for the jumpbox instance
    # @return [Aws::EC2::Types::Instance]
    def create(config)
      PlatformOps::Utils.validated_config config, %i(ami_id ssh_user)

      @ami_id = config[:ami_id]
      @ssh_user = config[:ssh_user]
      @ingress_cidrs = combine_ingress_addresses(config[:ingress_ip], config[:ingress_cidrs])
      @ssh_public_key_path = config[:ssh_public_key] || '~/.ssh/id_rsa.pub'
      @ssh_private_key_path = config[:ssh_private_key] || '~/.ssh/id_rsa'
      @ssh_poll_private_ip = config[:ssh_poll_private_ip]
      @security_group_connections = config[:security_group_connections] || []
      @eip_allocation_id = config[:eip_allocation_id]
      @instance_type = config[:instance_type] || 't2.medium'
      @cidr = config[:cidr]

      begin
        route_table_id    = create_route_table
        subnet_id         = create_subnet(route_table_id, @cidr)
        security_group_id = create_security_group(security_group_connections)
        instance_id       = create_instance(subnet_id, security_group_id)
        instance          = wait_for_instance(instance_id)
        associate_eip(instance_id) if @eip_allocation_id
        instance
      rescue Interrupt, StandardError => e
        logger.error e

        destroy

        raise
      end
    end

    # Creates a jump box, yields it to the supplied block, then destroys it when the block exits
    # @see #create for config options
    # @yieldparam instance [Aws::EC2::Types::Instance] jump box instance
    def with_instance(config)
      raise ArgumentError.new('Block required when calling JumpBox#with_instance') unless block_given?
      instance = create(config)
      yield instance
    ensure
      destroy
    end

    # Destroys the jump box based on the 'identifier' property
    def destroy
      resources = find_resources_by_tag

      destroy_instance(resources)
      destroy_security_group(resources)
      destroy_subnet(resources)
      destroy_route_table(resources)

      nil
    end

    private

    def create_random_identifier
      SecureRandom.hex.slice(10, 10)
    end

    def ec2
      @ec2 ||= Aws::EC2::Client.new(aws_client_options)
    end

    def vpc
      @vpc ||= Aws::EC2::Vpc.new(vpc_id, aws_client_options)
    end

    def combine_ingress_addresses(ingress_ip, ingress_cidrs)
      my_ip = PlatformOps::Networking.my_public_ip
      addresses = my_ip ? ["#{my_ip}/32"] : []

      if ingress_ip
        logger.warn 'WARNING: The :ingress_ip option for PlatformOps::JumpBox is deprecated in favour of the :ingress_cidrs option.'
        addresses << "#{ingress_ip}/32"
      end

      addresses.push(*ingress_cidrs) if ingress_cidrs
      addresses.uniq
    end
  end
end
