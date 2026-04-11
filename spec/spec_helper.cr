require "spec"

def fixture_path(filename : String) : String
  File.join(__DIR__, "fixtures", filename)
end

def with_source_file(fixture : String, source_path : String, &block)
  begin
    FileUtils.mkdir_p(File.dirname(source_path))
    FileUtils.cp(fixture_path(fixture), source_path)
    yield
  ensure
    File.delete(source_path)
  end
end

def with_test_server(server_context_proc : Proc(HTTP::Server::Context, Nil), &block)
  server = HTTP::Server.new(server_context_proc)
  begin
    addr = server.bind_unused_port
    spawn { server.listen }
    yield addr
  ensure
    server.close
  end
end

def with_temp_cache_dir(name_prefix : String, &block : String ->)
  cache_dir = File.join(Dir.tempdir, "#{name_prefix}_#{Process.pid}_#{Time.utc.to_unix_ms}_#{Random.rand(1_000_000)}")
  begin
    FileUtils.mkdir_p(cache_dir)
    yield cache_dir
  ensure
    FileUtils.rm_rf(cache_dir)
  end
end

def with_cached_file(path : String, body : String, &block)
  begin
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, body)
    yield
  ensure
    File.delete(path) if File.exists?(path)
  end
end
