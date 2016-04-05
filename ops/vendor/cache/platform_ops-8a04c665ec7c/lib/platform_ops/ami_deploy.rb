require_relative 'logging'
require_relative 'deployment/simple_deployer'
require_relative 'deployment/rolling_deployer'

module PlatformOps
  class AmiDeploy
    include PlatformOps::Logging

    def initialize(config)
      config[:deployment_strategy] ||= :simple

      @deployer = case config[:deployment_strategy].to_sym
        when :simple
          logger.info 'Chose simple deployment strategy'
          PlatformOps::Deployment::SimpleDeployer.new(config)
        when :rolling
          logger.info 'Chose blue/green deployment strategy'
          PlatformOps::Deployment::RollingDeployer.new(config)
        else
          raise ArgumentError.new("Unsupported deployment strategy #{config[:deployment_strategy]}")
      end
    end

    def deploy
      @deployer.deploy
    end

    def delete
      @deployer.delete
    end
  end
end
