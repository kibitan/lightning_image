require "log"

module LightningImage
  module Log
    APP_SOURCE = "lightning_image"

    def self.setup_from_env
      ::Log.setup_from_env
    end

    def self.logger
      @@logger ||= ::Log.for(APP_SOURCE)
    end

    def self.debug(message)
      logger.debug &.emit(message, file: __FILE__, line: __LINE__)
    end
  end
end
