require "../extensions/http_server_context"
require "../extensions/log"
require "../constants"

module LightningImage
  class SendFileHandler
    include HTTP::Handler

    def initialize(@x_send_file_header : String, @x_send_file_location : String, @cache_control_header : String, @etag : Bool, @last_modified : Bool); end

    def call(context)
      # definition: https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Content-Type
      context.response.content_type = context.image_cache.not_nil!.content_type

      # definition: https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Cache-Control
      context.response.headers.add "Cache-Control", @cache_control_header

      # definition: https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Last-Modified
      # last modified implementation in nginx: https://github.com/nginx/nginx/blob/stable-1.30/src/http/modules/ngx_http_static_module.c#L231
      if @last_modified
        context.response.headers.add "Last-Modified", context.image_cache.not_nil!.last_modified

        if context.request.headers.has_key?("If-Modified-Since") &&
            context.image_cache.not_nil!.modification_time <= Time.parse(
              context.request.headers["If-Modified-Since"]?.not_nil!,
              "%a, %d %b %Y %H:%M:%S GMT",
              Time::Location::UTC
            )
          context.response.status_code = 304
          return
        end
      end

      if @etag
        context.response.headers.add "ETag", context.image_cache.not_nil!.etag

        if context.image_cache.not_nil!.etag == context.request.headers["If-None-Match"]?
          context.response.status_code = 304
          return
        end
      end

      context.response.status_code = 200

      if @x_send_file_header.blank?
        Log.debug("Sending file directly: #{context.image_cache.not_nil!.path}")
        context.response.print File.read(context.image_cache.not_nil!.path)
      else
        x_send_file_path = "#{@x_send_file_location}/#{context.image_cache.not_nil!.path.lstrip("./")}"
        # X-Accel-Redirect uses URI path semantics and nginx decodes once.
        # Cache filenames include literal '%' (e.g. %20), so we escape '%'
        # to keep the internal redirect path aligned with on-disk filenames.
        if @x_send_file_header == "X-Accel-Redirect"
          x_send_file_path = x_send_file_path.gsub("%", "%25")
        end
        Log.debug("Sending file with header: #{x_send_file_path}")
        context.response.headers.add @x_send_file_header, x_send_file_path
      end
    end
  end
end
