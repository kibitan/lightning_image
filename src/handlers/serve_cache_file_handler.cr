require "../extensions/http_server_context"
require "../extensions/log"
require "../constants"
require "./send_file_handler"

module LightningImage
  class ServeCacheFileHandler
    include HTTP::Handler

    def initialize(@serve_cache : Bool, @cache_dir : String, @send_file_handler : SendFileHandler)
    end

    def call(context)
      if context.image_cache.not_nil!.exists?
        if @serve_cache
          Log.debug("Serving cached file: #{context.image_cache.not_nil!.path}")
          @send_file_handler.call(context)
          return
        else
          Log.debug("Serving cache is disabled: #{context.image_cache.not_nil!.path}")
          context.response.status_code = 409 # conflict
          context.response.content_type = "text/plain"
          context.response.print "Conflict: Cache file already exists: #{context.image_cache.not_nil!.path}"
          return
        end
      else
        call_next(context)
      end
    end
  end
end
