require "http/server/handler"
require "../constants"

module LightningImage
  class PingHandler
    include HTTP::Handler

    def call(context)
      if context.request.path == LightningImage::HEALTH_CHECK_PATH
        context.response.status_code = 200
        context.response.content_type = "text/plain"
        context.response.print "pong!"
        return
      else
        call_next(context)
      end
    end
  end
end
