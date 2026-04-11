require "../extensions/http_server_context"
require "../extensions/log"
require "../models/image_cache"
require "../constants"

module LightningImage
  class ParsePathParametersHandler
    include HTTP::Handler

    def initialize(@cache_dir : String); end

    def call(context)
      context.image_cache = ImageCache.parse_from_path(context.request.uri.to_s, @cache_dir)

      call_next(context)
    rescue ImageCache::InvalidPathError
      Log.debug("invalid request path: #{context.request.path}")
      context.response.status_code = 400
      context.response.content_type = "text/plain"
      context.response.print "Bad Request: #{context.request.path}"
      return
    end
  end
end
