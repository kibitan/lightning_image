require "../spec_helper"
require "http/server"
require "../../src/models/image_cache"
require "file_utils"
require "vips"

describe LightningImage::ImageCache do
  describe ".parse_from_path" do
    it "parses format, dimensions, URL, and fit=false when _fit is absent" do
      cache_dir = "/tmp/cache"
      path = "/webp/800x600/https://example.com/images/cat.png"

      image_cache = LightningImage::ImageCache.parse_from_path(path, cache_dir)

      image_cache.format.should eq("webp")
      image_cache.image_url.should eq("https://example.com/images/cat.png")
      image_cache.width.should eq(800)
      image_cache.height.should eq(600)
      image_cache.fit.should be_false
    end

    it "parses when width and height are omitted and _fit is absent" do
      cache_dir = "/tmp/cache"
      path = "/webp/x/https://example.com/images/cat.png"

      image_cache = LightningImage::ImageCache.parse_from_path(path, cache_dir)

      image_cache.format.should eq("webp")
      image_cache.image_url.should eq("https://example.com/images/cat.png")
      image_cache.width.should be_nil
      image_cache.height.should be_nil
      image_cache.fit.should be_false
    end

    it "parses when height is omitted and _fit is absent" do
      cache_dir = "/tmp/cache"
      path = "/webp/800x/https://example.com/images/cat.png"

      image_cache = LightningImage::ImageCache.parse_from_path(path, cache_dir)

      image_cache.format.should eq("webp")
      image_cache.image_url.should eq("https://example.com/images/cat.png")
      image_cache.width.should eq(800)
      image_cache.height.should be_nil
      image_cache.fit.should be_false
    end

    it "parses when width is omitted and _fit is absent" do
      cache_dir = "/tmp/cache"
      path = "/webp/x600/https://example.com/images/cat.png"

      image_cache = LightningImage::ImageCache.parse_from_path(path, cache_dir)

      image_cache.format.should eq("webp")
      image_cache.image_url.should eq("https://example.com/images/cat.png")
      image_cache.width.should be_nil
      image_cache.height.should eq(600)
      image_cache.fit.should be_false
    end

    it "parses format, dimensions, URL, and fit=true when the path includes the fit suffix" do
      cache_dir = "/tmp/cache"
      path = "/webp/800x600_fit/https://example.com/images/cat.png"

      image_cache = LightningImage::ImageCache.parse_from_path(path, cache_dir)

      image_cache.format.should eq("webp")
      image_cache.image_url.should eq("https://example.com/images/cat.png")
      image_cache.width.should eq(800)
      image_cache.height.should eq(600)
      image_cache.fit.should be_true
    end

    it "parses when width and height are omitted and _fit is present (doesn't make sense though)" do
      cache_dir = "/tmp/cache"
      path = "/webp/x_fit/https://example.com/images/cat.png"

      image_cache = LightningImage::ImageCache.parse_from_path(path, cache_dir)

      image_cache.format.should eq("webp")
      image_cache.image_url.should eq("https://example.com/images/cat.png")
      image_cache.width.should be_nil
      image_cache.height.should be_nil
      image_cache.fit.should be_true
    end

    it "parses URL when get parameters are present" do
      cache_dir = "/tmp/cache"
      path = "/webp/800x600/https://www.ehotel.de/ImgX/image?imageId=5979284990"

      image_cache = LightningImage::ImageCache.parse_from_path(path, cache_dir)

      image_cache.format.should eq("webp")
      image_cache.image_url.should eq("https://www.ehotel.de/ImgX/image?imageId=5979284990")
      image_cache.width.should eq(800)
      image_cache.height.should eq(600)
      image_cache.fit.should be_false
    end

    it "raises InvalidPathError when the path does not match the expected pattern" do
      expect_raises(LightningImage::ImageCache::InvalidPathError) do
        LightningImage::ImageCache.parse_from_path("/not-a-valid-cache-path", "/tmp/cache")
      end
    end
  end

  describe "getters" do
    it "exposes format, image_url, width, and height" do
      image_cache = LightningImage::ImageCache.new(
        cache_dir: "/tmp/cache",
        format: "webp",
        image_url: "https://example.com/images/cat.png",
        width: 123,
        height: 456
      )

      image_cache.format.should eq("webp")
      image_cache.image_url.should eq("https://example.com/images/cat.png")
      image_cache.width.should eq(123)
      image_cache.height.should eq(456)
    end

    it "defaults width/height to nil" do
      image_cache = LightningImage::ImageCache.new(
        cache_dir: "/tmp/cache",
        format: "webp",
        image_url: "https://example.com/images/cat.png"
      )

      image_cache.width.should be_nil
      image_cache.height.should be_nil
    end
  end

  describe "#source_path" do
    it "builds a source path under source/ using the image URL components" do
      cache_dir = "/tmp/cache"
      format = "webp"
      image_url = "https://example.com/images/cat.png"

      image_cache = LightningImage::ImageCache.new(
        cache_dir: cache_dir,
        format: format,
        image_url: image_url
      )

      expected = "/tmp/cache/source/https://example.com/images/cat.png"
      image_cache.source_path.should eq(expected)
    end
  end

  describe "#source_exists?" do
    it "returns false when the source file does not exist" do
      with_temp_cache_dir("lightning_image_source_exists") do |cache_dir|
        image_cache = LightningImage::ImageCache.new(
          cache_dir: cache_dir,
          format: "webp",
          image_url: "https://example.com/images/cat.png"
        )
        image_cache.source_exists?.should be_false
      end
    end

    it "returns true when the source file exists at source_path" do
      with_temp_cache_dir("lightning_image_source_exists") do |cache_dir|
        image_cache = LightningImage::ImageCache.new(
          cache_dir: cache_dir,
          format: "webp",
          image_url: "https://example.com/images/cat.png"
        )
        with_source_file("source_17x13.png", image_cache.source_path) do
          image_cache.source_exists?.should be_true
        end
      end
    end
  end

  describe "#fetch_source!" do
    it "writes the response body to source_path when Content-Type is image/*" do
      body = File.read(fixture_path("source_17x13.png"))
      server_context = ->(ctx : HTTP::Server::Context) {
        ctx.response.content_type = "image/png"
        ctx.response.print body
      }

      with_temp_cache_dir("lightning_image_fetch_source") do |cache_dir|
        with_test_server(server_context) do |addr|
          image_url = "http://#{addr.address}:#{addr.port}/photo.png"
          image_cache = LightningImage::ImageCache.new(
            cache_dir: cache_dir,
            format: "webp",
            image_url: image_url
          )
          image_cache.fetch_source!(check_content_type: true, timeout: 100.milliseconds)
          File.read(image_cache.source_path).should eq(body)
        end
      end
    end

    it "writes the response body to source_path with query parameters" do
      body = File.read(fixture_path("source_17x13.png"))
      server_context = ->(ctx : HTTP::Server::Context) {
        ctx.response.content_type = "image/png"
        ctx.response.print body
      }

      with_temp_cache_dir("lightning_image_fetch_source") do |cache_dir|
        with_test_server(server_context) do |addr|
          image_url = "http://#{addr.address}:#{addr.port}/photo.png?w=100&h=100#header"
          image_cache = LightningImage::ImageCache.new(
            cache_dir: cache_dir,
            format: "webp",
            image_url: image_url
          )
          image_cache.fetch_source!(check_content_type: true, timeout: 100.milliseconds)
          File.read(image_cache.source_path).should eq(body)
        end
      end
    end

    it "raises UnsupportedMediaTypeError when Content-Type is not an image" do
      server_context = ->(ctx : HTTP::Server::Context) {
        ctx.response.content_type = "text/html"
        ctx.response.print "<html/>"
      }

      with_temp_cache_dir("lightning_image_fetch_source") do |cache_dir|
        with_test_server(server_context) do |addr|
          image_url = "http://#{addr.address}:#{addr.port}/page.html"
          image_cache = LightningImage::ImageCache.new(
            cache_dir: cache_dir,
            format: "webp",
            image_url: image_url
          )
          expect_raises(LightningImage::ImageCache::UnsupportedMediaTypeError, "fetch failed: not supported content type: text/html") do
            image_cache.fetch_source!(check_content_type: true, timeout: 100.milliseconds)
          end
          image_cache.source_exists?.should be_false
        end
      end
    end

    [
      {"2xx", 200},
      {"2xx", 210},
    ].each do |status_class, status_code|
      it "writes source for happy-path #{status_class} status #{status_code}" do
        body = "status-#{status_code}"
        server_context = ->(ctx : HTTP::Server::Context) {
          ctx.response.status_code = status_code
          ctx.response.content_type = "image/png"
          ctx.response.print body
        }

        with_temp_cache_dir("lightning_image_fetch_source") do |cache_dir|
          with_test_server(server_context) do |addr|
            image_url = "http://#{addr.address}:#{addr.port}/status-#{status_code}"
            image_cache = LightningImage::ImageCache.new(
              cache_dir: cache_dir,
              format: "webp",
              image_url: image_url
            )
            image_cache.fetch_source!(check_content_type: true, timeout: 100.milliseconds)
            File.read(image_cache.source_path).should eq(body)
          end
        end
      end
    end

    [
      {"1xx", 101},
      {"3xx", 302},
      {"4xx", 404},
      {"5xx", 500},
    ].each do |status_class, status_code|
      it "raises for unhappy-path #{status_class} status #{status_code}" do
        body = "status-#{status_code}"
        server_context = ->(ctx : HTTP::Server::Context) {
          ctx.response.status_code = status_code
          ctx.response.content_type = "image/png"
          ctx.response.print body
        }

        with_temp_cache_dir("lightning_image_fetch_source") do |cache_dir|
          with_test_server(server_context) do |addr|
            image_url = "http://#{addr.address}:#{addr.port}/status-#{status_code}"
            image_cache = LightningImage::ImageCache.new(
              cache_dir: cache_dir,
              format: "webp",
              image_url: image_url
            )
            expect_raises(LightningImage::ImageCache::FailedToFetchSourceImageError, "fetch failed: status code is #{status_code}") do
              image_cache.fetch_source!(check_content_type: true, timeout: 100.milliseconds)
            end
            image_cache.source_exists?.should be_false
          end
        end
      end
    end

    it "raises UnsupportedMediaTypeError when Content-Type is missing" do
      server_context = ->(ctx : HTTP::Server::Context) {
        ctx.response.print "not-an-image"
      }

      with_temp_cache_dir("lightning_image_fetch_source") do |cache_dir|
        with_test_server(server_context) do |addr|
          image_url = "http://#{addr.address}:#{addr.port}/blob"
          image_cache = LightningImage::ImageCache.new(
            cache_dir: cache_dir,
            format: "webp",
            image_url: image_url
          )
          expect_raises(LightningImage::ImageCache::NoContentTypeError, "fetch failed: no content type") do
            image_cache.fetch_source!(check_content_type: true, timeout: 100.milliseconds)
          end
          image_cache.source_exists?.should be_false
        end
      end
    end

    [
      {"Content-Type is not an image", "<html/>", "text/html", "page.html"},
      {"Content-Type is missing", "not-an-image", nil, "blob"},
    ].each do |case_name, body, content_type, path_tail|
      it "writes source when #{case_name} and check_content_type is false" do
        server_context = ->(ctx : HTTP::Server::Context) {
          ctx.response.content_type = content_type if content_type
          ctx.response.print body
        }

        with_temp_cache_dir("lightning_image_fetch_source") do |cache_dir|
          with_test_server(server_context) do |addr|
            image_url = "http://#{addr.address}:#{addr.port}/#{path_tail}"
            image_cache = LightningImage::ImageCache.new(
              cache_dir: cache_dir,
              format: "webp",
              image_url: image_url
            )
            image_cache.fetch_source!(check_content_type: false, timeout: 100.milliseconds)
            File.read(image_cache.source_path).should eq(body)
          end
        end
      end
    end

    it "raises FailedToFetchSourceImageError when timeout fails" do
      body = "ok"
      server_context = ->(ctx : HTTP::Server::Context) {
        sleep 5.milliseconds
        ctx.response.status_code = 200
        ctx.response.content_type = "image/png"
        ctx.response.print body
      }

      with_temp_cache_dir("lightning_image_fetch_source") do |cache_dir|
        with_test_server(server_context) do |addr|
          image_url = "http://#{addr.address}:#{addr.port}/blob"
          image_cache = LightningImage::ImageCache.new(
            cache_dir: cache_dir,
            format: "webp",
            image_url: image_url
          )
          expect_raises(LightningImage::ImageCache::FailedToFetchSourceImageError, "fetch failed: Read timed out") do
            image_cache.fetch_source!(check_content_type: true, timeout: 1.milliseconds)
          end
          image_cache.source_exists?.should be_false
        end
      end
    end

    [
      {
        "Socket::Error",
        "http://127.0.0.1:1/blob",
        "fetch failed: Error connecting to '127.0.0.1:1': Connection refused",
      },
      {
        "hostname lookup failure",
        "http://xxx.example.com/blob",
        "fetch failed: Hostname lookup for xxx.example.com failed: No address found",
      },
      {
        "invalid URL",
        "http:///blob",
        "fetch failed: Error connecting to ':80': Connection refused",
      },
    ].each do |case_name, image_url, expected_error|
      it "raises FailedToFetchSourceImageError when #{case_name} occurs" do
        with_temp_cache_dir("lightning_image_fetch_source") do |cache_dir|
          image_cache = LightningImage::ImageCache.new(
            cache_dir: cache_dir,
            format: "webp",
            image_url: image_url
          )

          expect_raises(LightningImage::ImageCache::FailedToFetchSourceImageError, expected_error) do
            image_cache.fetch_source!(check_content_type: true, timeout: 100.milliseconds)
          end
          image_cache.source_exists?.should be_false
        end
      end
    end
  end

  describe "#convert_from_source!" do
    [
      {"width and height are nil", nil, nil},
      {"width is nil", nil, 10},
      {"height is nil", 10, nil},
    ].each do |case_name, width, height|
      it "writes webp to path without resizing when #{case_name}" do
        with_temp_cache_dir("lightning_image_convert") do |cache_dir|
          image_cache = LightningImage::ImageCache.new(
            cache_dir: cache_dir,
            format: "webp",
            image_url: "https://example.com/images/test.png",
            width: width,
            height: height
          )
          with_source_file("source_17x13.png", image_cache.source_path) do
            image_cache.convert_from_source!(allow_upsize_image: false)
            image_cache.exists?.should be_true
            out = Vips::Image.new_from_file(image_cache.path)
            out.width.should eq(17)
            out.height.should eq(13)
          end
        end
      end
    end

    [
      {"Size::Down when fit is false", false, 10, 5},
      {"Size::Force when fit is true", true, 10, 10},
    ].each do |case_name, fit, expected_width, expected_height|
      it "writes webp using thumbnail with #{case_name}" do
        with_temp_cache_dir("lightning_image_convert") do |cache_dir|
          image_cache = LightningImage::ImageCache.new(
            cache_dir: cache_dir,
            format: "webp",
            image_url: "https://example.com/images/test.png",
            width: 10,
            height: 10,
            fit: fit
          )
          with_source_file("source_40x20.png", image_cache.source_path) do
            image_cache.convert_from_source!(allow_upsize_image: false)
            image_cache.exists?.should be_true
            out = Vips::Image.new_from_file(image_cache.path)
            out.width.should eq(expected_width)
            out.height.should eq(expected_height)
          end
        end
      end
    end

    [
      {"allow_upsize_image is false", false, 40, 20},
      {"allow_upsize_image is true", true, 80, 40},
    ].each do |case_name, allow_upsize_image, expected_width, expected_height|
      it "keeps source size for #{case_name} when requested size is larger than source" do
        with_temp_cache_dir("lightning_image_convert") do |cache_dir|
          image_cache = LightningImage::ImageCache.new(
            cache_dir: cache_dir,
            format: "webp",
            image_url: "https://example.com/images/test.png",
            width: 80,
            height: 40,
            fit: false
          )
          with_source_file("source_40x20.png", image_cache.source_path) do
            image_cache.convert_from_source!(allow_upsize_image: allow_upsize_image)
            image_cache.exists?.should be_true
            out = Vips::Image.new_from_file(image_cache.path)
            out.width.should eq(expected_width)
            out.height.should eq(expected_height)
          end
        end
      end
    end
  end

  describe "#exists?" do
    it "returns false when the cached file does not exist" do
      with_temp_cache_dir("lightning_image_exists") do |cache_dir|
        image_cache = LightningImage::ImageCache.new(
          cache_dir: cache_dir,
          format: "webp",
          image_url: "https://example.com/images/cat.png"
        )
        image_cache.exists?.should be_false
      end
    end

    it "returns true when the cached file exists at path" do
      with_temp_cache_dir("lightning_image_exists") do |cache_dir|
        image_cache = LightningImage::ImageCache.new(
          cache_dir: cache_dir,
          format: "webp",
          image_url: "https://example.com/images/cat.png"
        )
        FileUtils.mkdir_p(File.dirname(image_cache.path))
        File.write(image_cache.path, "x")
        image_cache.exists?.should be_true
      end
    end
  end

  describe "#path" do
    it "builds the formatted cached image path" do
      cache_dir = "/tmp/cache"
      format = "webp"
      image_url = "https://example.com/images/cat.png"

      image_cache = LightningImage::ImageCache.new(
        cache_dir: cache_dir,
        format: format,
        image_url: image_url
      )

      expected = "/tmp/cache/webp/x/https://example.com/images/cat.png"
      image_cache.path.should eq(expected)
    end

    it "builds the formatted cached image path" do
      cache_dir = "/tmp/cache"
      format = "webp"
      image_url = "https://example.com/images/cat.png"

      image_cache = LightningImage::ImageCache.new(
        cache_dir: cache_dir,
        format: format,
        image_url: image_url,
        width: 123,
        height: 456
      )

      expected = "/tmp/cache/webp/123x456/https://example.com/images/cat.png"
      image_cache.path.should eq(expected)
    end

    it "builds the formatted cached image path with fit" do
      cache_dir = "/tmp/cache"
      format = "webp"
      image_url = "https://example.com/images/cat.png"

      image_cache = LightningImage::ImageCache.new(
        cache_dir: cache_dir,
        format: format,
        image_url: image_url,
        width: 123,
        height: 456,
        fit: true
      )

      expected = "/tmp/cache/webp/123x456_fit/https://example.com/images/cat.png"
      image_cache.path.should eq(expected)
    end
  end

  describe "#content_type" do
    it "returns image MIME type from format" do
      image_cache = LightningImage::ImageCache.new(
        cache_dir: "/tmp/cache",
        format: "webp",
        image_url: "https://example.com/images/cat.png"
      )

      image_cache.content_type.should eq("image/webp")
    end
  end

  describe "#etag / #modification_time / #last_modified" do
    it "builds nginx-compatible etag and exposes modification times" do
      with_temp_cache_dir("lightning_image_metadata") do |cache_dir|
        image_cache = LightningImage::ImageCache.new(
          cache_dir: cache_dir,
          format: "webp",
          image_url: "https://example.com/images/cat.png"
        )
        body = "etag-body"
        expected_modification_time = Time.utc(2015, 10, 21, 7, 28, 0)

        with_cached_file(image_cache.path, body) do
          File.touch(image_cache.path, time: expected_modification_time)

          image_cache.modification_time.to_unix.should eq(expected_modification_time.to_unix)
          image_cache.last_modified.should eq("Wed, 21 Oct 2015 07:28:00 GMT")
          image_cache.etag.should eq("\"56273e80-9\"")
        end
      end
    end
  end
end
