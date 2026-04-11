require "../extensions/http_server_context"
require "../models/allow_list"

module LightningImage
  class ValidateURLHandler
    include HTTP::Handler

    def initialize(@allow_list : AllowList); end

    def call(context)
      if @allow_list.allowed?(context.image_cache.not_nil!.image_url)
        call_next(context)
      else
        context.response.status_code = 403
        context.response.content_type = "text/plain"
        context.response.print "Forbidden: #{context.image_cache.not_nil!.image_url}"
        return
      end
    end
  end
end
