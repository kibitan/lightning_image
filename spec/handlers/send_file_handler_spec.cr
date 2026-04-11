require "../spec_helper"
require "file_utils"
require "../../src/handlers/send_file_handler"

describe LightningImage::SendFileHandler do
  it "sends file contents when x-send-file header is blank" do
    with_temp_cache_dir("lightning_image_send_file_handler") do |cache_dir|
      image_cache = LightningImage::ImageCache.new(
        cache_dir: cache_dir,
        format: "webp",
        image_url: "https://example.com/images/cat.png"
      )
      expected_body = "binary-image-bytes"

      with_cached_file(image_cache.path, expected_body) do
        last_modified = Time.utc(2015, 10, 21, 7, 28, 0)
        File.touch(image_cache.path, time: last_modified)

        handler = LightningImage::SendFileHandler.new("", "", "public, max-age=600", true, true)
        server_context = ->(ctx : HTTP::Server::Context) {
          ctx.image_cache = image_cache
          handler.call(ctx)
        }

        with_test_server(server_context) do |addr|
          response = HTTP::Client.get("http://#{addr.address}:#{addr.port}/")

          response.status_code.should eq(200)
          response.content_type.should eq("image/webp")
          response.headers["Cache-Control"].should eq("public, max-age=600")
          response.headers["Last-Modified"].should eq("Wed, 21 Oct 2015 07:28:00 GMT")
          response.headers["ETag"].should eq("\"56273e80-12\"")
          response.body.should eq(expected_body)
        end
      end
    end
  end

  it "sets configured x-send-file header instead of writing body when configured" do
    with_temp_cache_dir("lightning_image_send_file_handler") do |cache_dir|
      image_cache = LightningImage::ImageCache.new(
        cache_dir: cache_dir,
        format: "webp",
        image_url: "https://example.com/images/cat.png"
      )
      with_cached_file(image_cache.path, "ignored") do
        last_modified = Time.utc(2026, 4, 27, 10, 10, 10)
        File.touch(image_cache.path, time: last_modified)

        handler = LightningImage::SendFileHandler.new("X-Send-File", "/x-accel-redirect", "private, max-age=60, no-store", true, true)
        server_context = ->(ctx : HTTP::Server::Context) {
          ctx.image_cache = image_cache
          handler.call(ctx)
        }

        with_test_server(server_context) do |addr|
          response = HTTP::Client.get("http://#{addr.address}:#{addr.port}/")

          response.status_code.should eq(200)
          response.content_type.should eq("image/webp")
          response.headers["Cache-Control"].should eq("private, max-age=60, no-store")
          response.headers["Last-Modified"].should eq("Mon, 27 Apr 2026 10:10:10 GMT")
          response.headers["ETag"].should eq("\"69ef3602-7\"")
          response.headers["X-Send-File"].should eq("/x-accel-redirect#{image_cache.path}")
          response.body.should eq("")
        end
      end
    end
  end

  it "escapes percent signs in x-accel-redirect header path" do
    with_temp_cache_dir("lightning_image_send_file_handler") do |cache_dir|
      image_cache = LightningImage::ImageCache.new(
        cache_dir: cache_dir,
        format: "webp",
        image_url: "https://example.com/images/cat%20photo.png"
      )
      with_cached_file(image_cache.path, "ignored") do
        last_modified = Time.utc(2026, 4, 27, 10, 10, 10)
        File.touch(image_cache.path, time: last_modified)

        handler = LightningImage::SendFileHandler.new("X-Accel-Redirect", "/x-accel-redirect", "private, max-age=60, no-store", true, true)
        server_context = ->(ctx : HTTP::Server::Context) {
          ctx.image_cache = image_cache
          handler.call(ctx)
        }

        with_test_server(server_context) do |addr|
          response = HTTP::Client.get("http://#{addr.address}:#{addr.port}/")
          expected_path = "/x-accel-redirect#{cache_dir}/webp/x/https://example.com/images/cat%2520photo.png"

          response.status_code.should eq(200)
          response.headers["X-Accel-Redirect"].should eq(expected_path)
        end
      end
    end
  end

  it "does not set ETag header when etag toggle is false" do
    with_temp_cache_dir("lightning_image_send_file_handler") do |cache_dir|
      image_cache = LightningImage::ImageCache.new(
        cache_dir: cache_dir,
        format: "webp",
        image_url: "https://example.com/images/cat.png"
      )
      with_cached_file(image_cache.path, "etag-disabled") do
        last_modified = Time.utc(2015, 10, 21, 7, 28, 0)
        File.touch(image_cache.path, time: last_modified)

        handler = LightningImage::SendFileHandler.new("X-Send-File", "", "public, max-age=600", false, true)
        server_context = ->(ctx : HTTP::Server::Context) {
          ctx.image_cache = image_cache
          handler.call(ctx)
        }

        with_test_server(server_context) do |addr|
          response = HTTP::Client.get("http://#{addr.address}:#{addr.port}/")
          response.headers["ETag"]?.should be_nil
          response.headers["Last-Modified"].should eq("Wed, 21 Oct 2015 07:28:00 GMT")
        end
      end
    end
  end

  it "returns 304 when If-None-Match matches generated ETag" do
    with_temp_cache_dir("lightning_image_send_file_handler") do |cache_dir|
      image_cache = LightningImage::ImageCache.new(
        cache_dir: cache_dir,
        format: "webp",
        image_url: "https://example.com/images/cat.png"
      )
      with_cached_file(image_cache.path, "not-modified") do
        last_modified = Time.utc(2015, 10, 21, 7, 28, 0)
        File.touch(image_cache.path, time: last_modified)
        expected_etag = "\"56273e80-c\""

        handler = LightningImage::SendFileHandler.new("", "", "public, max-age=600", true, true)
        server_context = ->(ctx : HTTP::Server::Context) {
          ctx.image_cache = image_cache
          handler.call(ctx)
        }

        with_test_server(server_context) do |addr|
          headers = HTTP::Headers{"If-None-Match" => expected_etag}
          response = HTTP::Client.get("http://#{addr.address}:#{addr.port}/", headers: headers)

          response.status_code.should eq(304)
          response.headers["ETag"].should eq(expected_etag)
          response.body.should eq("")
        end
      end
    end
  end

  it "returns 304 when If-Modified-Since is equal to Last-Modified" do
    with_temp_cache_dir("lightning_image_send_file_handler") do |cache_dir|
      image_cache = LightningImage::ImageCache.new(
        cache_dir: cache_dir,
        format: "webp",
        image_url: "https://example.com/images/cat.png"
      )
      with_cached_file(image_cache.path, "ims-match") do
        last_modified = Time.utc(2015, 10, 21, 7, 28, 0)
        File.touch(image_cache.path, time: last_modified)
        if_modified_since = "Wed, 21 Oct 2015 07:28:00 GMT"

        handler = LightningImage::SendFileHandler.new("", "", "public, max-age=600", true, true)
        server_context = ->(ctx : HTTP::Server::Context) {
          ctx.image_cache = image_cache
          handler.call(ctx)
        }

        with_test_server(server_context) do |addr|
          headers = HTTP::Headers{"If-Modified-Since" => if_modified_since}
          response = HTTP::Client.get("http://#{addr.address}:#{addr.port}/", headers: headers)

          response.status_code.should eq(304)
          response.headers["Last-Modified"].should eq(if_modified_since)
          response.body.should eq("")
        end
      end
    end
  end

  it "returns 200 when If-Modified-Since is older than Last-Modified" do
    with_temp_cache_dir("lightning_image_send_file_handler") do |cache_dir|
      image_cache = LightningImage::ImageCache.new(
        cache_dir: cache_dir,
        format: "webp",
        image_url: "https://example.com/images/cat.png"
      )
      body = "ims-stale"
      with_cached_file(image_cache.path, body) do
        last_modified = Time.utc(2015, 10, 21, 7, 28, 0)
        File.touch(image_cache.path, time: last_modified)

        handler = LightningImage::SendFileHandler.new("", "", "public, max-age=600", true, true)
        server_context = ->(ctx : HTTP::Server::Context) {
          ctx.image_cache = image_cache
          handler.call(ctx)
        }

        with_test_server(server_context) do |addr|
          headers = HTTP::Headers{"If-Modified-Since" => "Tue, 20 Oct 2015 07:28:00 GMT"}
          response = HTTP::Client.get("http://#{addr.address}:#{addr.port}/", headers: headers)

          response.status_code.should eq(200)
          response.headers["Last-Modified"].should eq("Wed, 21 Oct 2015 07:28:00 GMT") # last modified should not be changed
          response.body.should eq(body)
        end
      end
    end
  end
end
