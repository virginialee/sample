require 'logger'

module PlatformOps
  module Logging

    def logger
      @logger ||= PlatformOps::Logging.logger_for(self.class.name)
    end

    @loggers = {}

    def self.logger_for(classname)
      @loggers[classname] ||= configure_logger_for(classname)
    end

    def self.configure_logger_for(classname)
      logger = Logger.new($stdout)
      logger.progname = classname
      logger.formatter = proc do |severity, datetime, progname, msg|
        "#{datetime} [#{progname}] #{msg}\n"
      end
      logger
    end

    def self.included(base)
      class << base
        def logger
          Logging.logger_for(name)
        end
      end
    end

  end
end
