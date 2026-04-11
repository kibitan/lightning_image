# Boost

Boost is a reverse-proxy configuration enabled for `lightning_image`.

It includes:
 * X-Accel-Redirect by nginx, faster than direct file serving
 * Cached file serving by nginx
 * UNIX socket connection support
 * HTTP/2 support (need to configure SSL/TLS)
 * ETag and Last-Modified support by nginx (etag implementation is compatible with nginx, so you can use the same etag with nginx and lightning_image)

## Sample Usage

```bash
cp nginx.conf.sample nginx.conf
cp docker-compose.yml.sample docker-compose.yml
docker-compose up -d
```

please check the nginx.conf.sample configuration as a sample configuration.
