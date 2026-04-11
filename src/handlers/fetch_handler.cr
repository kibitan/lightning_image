require "../extensions/http_server_context"
require "../extensions/log"

module LightningImage
  class FetchHandler
    include HTTP::Handler

    def initialize(@check_content_type : Bool, @source_fetch_timeout : Time::Span); end

    def call(context)
      if context.image_cache.not_nil!.source_exists?
        Log.debug("Skipping fetch: source image already cached: #{context.image_cache.not_nil!.source_path}")

        call_next(context)
        return
      end

      Log.debug("Fetching source image: #{context.image_cache.not_nil!.image_url}")
      context.image_cache.not_nil!.fetch_source!(check_content_type: @check_content_type, timeout: @source_fetch_timeout)

      call_next(context)
    rescue e : ImageCache::UnsupportedMediaTypeError | ImageCache::NoContentTypeError | ImageCache::FailedToFetchSourceImageError
      context.response.status_code = 400 # Bad Request
      context.response.content_type = "text/plain"
      context.response.print "Bad Request: #{e.message} #{context.image_cache.not_nil!.image_url}"
      return
    end
  end
end
