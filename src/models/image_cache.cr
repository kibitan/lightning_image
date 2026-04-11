require "../extensions/log"
require "../constants"
require "file_utils"
require "http/client"
require "vips"

module LightningImage
  struct ImageCache
    getter format : String
    getter image_url : String
    getter width : Int32?
    getter height : Int32?
    getter fit : Bool
    @cache_dir : String

    PATH_REGEX = /^\/(#{SUPPORTED_FORMATS.join("|")})\/(\d*)#{WIDTH_HEIGHT_SEPARATOR}(\d*)(#{FIT_SUFFIX})?\/(https?:\/\/.*)$/

    class InvalidPathError < Exception; end
    class UnsupportedMediaTypeError < Exception; end
    class FailedToFetchSourceImageError < Exception; end
    class NoContentTypeError < Exception; end

    def self.parse_from_path(path : String, cache_dir : String)
      match = PATH_REGEX.match(path)
      raise InvalidPathError.new if !match

      new(
        cache_dir,
        match[1],
        match[5],
        match[2].empty? ? nil : match[2].to_i,
        match[3].empty? ? nil : match[3].to_i,
        match[4]? ==  FIT_SUFFIX
      )
    end

    def initialize(cache_dir : String, format : String, image_url : String, width : Int32? = nil, height : Int32? = nil, fit : Bool = false)
      @cache_dir = cache_dir
      @format = format
      @image_url = image_url
      @width = width
      @height = height
      @fit = fit
    end

    def path
      "#{@cache_dir}/#{@format}/#{@width}#{WIDTH_HEIGHT_SEPARATOR}#{@height}#{@fit ? FIT_SUFFIX : ""}/#{File.dirname(@image_url)}/#{File.basename(@image_url)}"
    end

    def exists?
      File.exists?(path)
    end

    def source_path
      "#{@cache_dir}/#{SOURCE_DIR}/#{File.dirname(@image_url)}/#{File.basename(@image_url)}"
    end

    def source_exists?
      File.exists?(source_path)
    end

    def fetch_source!(check_content_type : Bool, timeout : Time::Span)
      uri = URI.parse @image_url
      client = HTTP::Client.new(uri.host || "", uri.port || (uri.scheme == "https" ? 443 : 80), tls: uri.scheme == "https")
      client.connect_timeout = timeout
      client.read_timeout = timeout

      begin
        response = client.get(uri.request_target)
      # https://crystal-lang.org/api/master/Socket/Error.html
      rescue ex : IO::TimeoutError | Socket::Error
        raise FailedToFetchSourceImageError.new("fetch failed: #{ex.message}")
      ensure
        client.close
      end

      # refs: https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Status
      if !(200 <= response.status_code < 300)
        raise FailedToFetchSourceImageError.new("fetch failed: status code is #{response.status_code}")
      end

      if check_content_type
        raise NoContentTypeError.new("fetch failed: no content type") if response.content_type.nil?
        # refs: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Content-Type
        raise UnsupportedMediaTypeError.new("fetch failed: not supported content type: #{response.content_type.not_nil!}") if !SUPPORTED_SOURCE_CONTENT_TYPES.includes?(response.content_type.not_nil!)
      end

      FileUtils.mkdir_p File.dirname(source_path)
      File.write source_path, response.body
    end

    def convert_from_source!(allow_upsize_image : Bool)
      image =
        if width.nil? || height.nil?
          Log.debug("Skipping resize: no width and/or height provided")
          Vips::Image.new_from_file(source_path)
        else
          Log.debug("Resizing image: #{source_path} to #{width}x#{height} with fit: #{fit} and allow_upsize_image: #{allow_upsize_image}, resize_mode: #{resize_mode(allow_upsize_image)}")
          Vips::Image.thumbnail(source_path, width.not_nil!, height: height.not_nil!, size: resize_mode(allow_upsize_image))
        end

      FileUtils.mkdir_p File.dirname(path)
      image.not_nil!.webpsave(path) # currently hardcode to webp
    end

    def content_type
      "image/#{format}"
    end

    # etag implementation in nginx: https://github.com/nginx/nginx/blob/stable-1.30/src/http/ngx_http_core_module.c#L1722-L1724
    def etag
      "\"#{file_info.modification_time.to_unix.to_s(16)}-#{file_info.size.to_s(16)}\""
    end

    def modification_time
      file_info.modification_time
    end

    def last_modified
      modification_time.to_utc.to_s("%a, %d %b %Y %H:%M:%S GMT")
    end

    private def resize_mode(allow_upsize_image : Bool)
      # refs: https://www.libvips.org/API/8.17/ctor.Image.thumbnail.html
      return Vips::Enums::Size::Force if fit
      return allow_upsize_image ? Vips::Enums::Size::Both : Vips::Enums::Size::Down
    end

    private def file_info
      @file_info ||= File.info(path)
    end
  end
end
