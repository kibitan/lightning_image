require "http/server"
require "./extensions/log"
require "./handlers/*"

module LightningImage
  VERSION = "0.1.0"
  PORT = ENV.fetch("PORT", "8080").to_i
  HOST = ENV.fetch("HOST", "0.0.0.0")
  UNIX_SOCKET = ENV.fetch("UNIX_SOCKET", "")
  CACHE_DIR = ENV.fetch("CACHE_DIR", "./cache")
  SERVE_CACHE = ENV.fetch("SERVE_CACHE", "true").to_s.downcase == "true"
  X_SEND_FILE_HEADER = ENV.fetch("X_SEND_FILE_HEADER", "")
  X_SEND_FILE_LOCATION = ENV.fetch("X_SEND_FILE_LOCATION", "")
  LOG_LEVEL = ENV.fetch("LOG_LEVEL", "info")
  CHECK_CONTENT_TYPE = ENV.fetch("CHECK_CONTENT_TYPE", "true").to_s.downcase == "true"
  ALLOW_UPSIZE_IMAGE = ENV.fetch("ALLOW_UPSIZE_IMAGE", "false").to_s.downcase == "true"
  SOURCE_FETCH_TIMEOUT_SECONDS = ENV.fetch("SOURCE_FETCH_TIMEOUT_SECONDS", "10").to_i
  ALLOW_LIST_FILE_PATH = ENV.fetch("ALLOW_LIST_FILE_PATH", "")
  CACHE_CONTROL_HEADER = ENV.fetch("CACHE_CONTROL_HEADER", "public, max-age=86400")
  ETAG = ENV.fetch("ETAG", "true").to_s.downcase == "true"
  LAST_MODIFIED = ENV.fetch("LAST_MODIFIED", "true").to_s.downcase == "true"

  def self.start
    Log.setup_from_env
    send_file_handler = SendFileHandler.new(X_SEND_FILE_HEADER, X_SEND_FILE_LOCATION, CACHE_CONTROL_HEADER, ETAG, LAST_MODIFIED)
    allow_list = ALLOW_LIST_FILE_PATH.empty? ? AllowEverything.new : AllowList.new(ALLOW_LIST_FILE_PATH)

    # https://crystal-lang.org/api/1.19.1/HTTP/Server.html#request-processing
    server = HTTP::Server.new([
      HTTP::LogHandler.new(Log.logger),
      PingHandler.new,
      ParsePathParametersHandler.new(CACHE_DIR),
      ValidateURLHandler.new(allow_list),
      ServeCacheFileHandler.new(SERVE_CACHE, CACHE_DIR, send_file_handler),
      FetchHandler.new(CHECK_CONTENT_TYPE, Time::Span.new(seconds: SOURCE_FETCH_TIMEOUT_SECONDS)),
      ConvertHandler.new(ALLOW_UPSIZE_IMAGE),
      send_file_handler
    ])

    address = if UNIX_SOCKET.blank?
      server.bind_tcp HOST, PORT
    else
      # Remove stale socket path from a crash or killed process; otherwise bind fails with EADDRINUSE.
      File.delete(UNIX_SOCKET) if File.exists?(UNIX_SOCKET)
      server.bind_unix UNIX_SOCKET
    end

    [Signal::INT, Signal::TERM].each do |signal|
      signal.trap do
        puts "Received #{signal}, shutting down..."
        server.close
      end
    end

    begin
      puts "Listening on #{UNIX_SOCKET.blank? ? "http://" : "unix:"}#{address} (log_level: #{LOG_LEVEL}, port: #{PORT}, unix_socket: #{UNIX_SOCKET}, serve_cache: #{SERVE_CACHE}, cache_dir: #{CACHE_DIR}, x_send_file_header: #{X_SEND_FILE_HEADER}, check_content_type: #{CHECK_CONTENT_TYPE}, allow_upsize_image: #{ALLOW_UPSIZE_IMAGE}, allow_list_file_path: #{ALLOW_LIST_FILE_PATH}, cache_control_header: #{CACHE_CONTROL_HEADER})"
      server.listen
    ensure
      server.close if !server.closed?
      File.delete(UNIX_SOCKET) if !UNIX_SOCKET.blank? && File.exists?(UNIX_SOCKET)
      puts "Finished shutting down server..."
    end
  end
end

LightningImage.start
