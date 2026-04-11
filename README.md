# Lightning Image

![Lightning Image](./docs/lightning_image.webp)

Image optimizing and cache engine ⚡️

this project is currently in WIP.

## Usage

```bash
./lightning_image
curl http://localhost:8080/webp/800x600/https://example.com/images/cat.png
```

`Last-Modified` and `ETag` is automatically set by the server.

### endpoints

####  `GET /<format>/<width>x<height><_fit>/<image_url>`: image optimization

- `<format>`: (required) The format of the image. Default is `webp`.
- `<width>`: (optional) The width of the image.
- `<height>`: (optional) The height of the image.
- `<_fit>`: (optional) Suffix to force resize the image without respecting the aspect ratio. if it's present, the image will be resized to the specified width and height without respecting the aspect ratio and `ALLOW_UPSIZE_IMAGE` will be ignored it could be upsized.
- `<image_url>`: (required) The URL of the image to fetch.

Note: If `<width>` or/and `<height>` are not provided, the image will not be resized.

e.g.

- `GET /webp/800x600/https://example.com/images/cat.png`
- `GET /webp/800x600_fit/https://example.com/images/cat.png`
- `GET /webp/x/https://example.com/images/cat.png`

### `GET /ping`: health check

- Returns `pong!` if the server is healthy.


### Environment Variables

- `PORT`: The port to listen on. Default is `8080`.
- `HOST`: The host to listen on. Default is `0.0.0.0`.
- `CACHE_DIR`: The directory to cache the images. Default is `./cache`.
- `SERVE_CACHE`: Whether to serve the cached images. Default is `true`. Set to `false` to disable serving cached images.
- `X_SEND_FILE_HEADER`: The header to use to send the file. Default is `""`. Set to a header name to use. (e.g. nginx: `X-Accel-Redirect`, apache: `X-Sendfile`)
- `X_SEND_FILE_LOCATION`: The location to send the file to. Default is `""`. Set to a location to send the file to. (e.g. nginx: `/x-accel-redirect`)
- `UNIX_SOCKET`: The path to the UNIX socket to listen on. Default is `""`. Set to a path to listen on a UNIX socket, it will disable listening on a TCP port.
- `LOG_LEVEL`: The log level to use. Default is `info`. Set to a log level to use. level details can be found at: https://crystal-lang.org/api/1.19.1/Log/Severity.html
- `CHECK_CONTENT_TYPE`: Whether to check the content type of the image. Default is `true`. Set to `false` to ignore the content type check.
- `ALLOW_UPSIZE_IMAGE`: Whether to allow the image to be resized to a larger size than the original image. Default is `false`. Set to `true` to allow the image to be resized to a larger size than the original image.
- `SOURCE_FETCH_TIMEOUT_SECONDS`: The timeout for fetching the source image. Default is `10`. Set to a timeout in seconds to use.
- `CACHE_CONTROL_HEADER`: Value of the `Cache-Control` response header. Default is `public, max-age=86400`.
- `ETAG`: Whether to set the `ETag` response header. Default is `true`. Set to `false` to disable the `ETag` header.
- `LAST_MODIFIED`: Whether to set the `Last-Modified` response header. Default is `true`. Set to `false` to disable the `Last-Modified` header.

### Allow List

- `ALLOW_LIST_FILE_PATH`: The path to the allow list file. Default is `""`. Set to a path to a file to use as an allow list. The file should contain one URL per line. The URL can be a regex. If the file is not present, all URLs will be allowed.

allow list should written in [regular expression format](https://crystal-lang.org/reference/syntax_and_semantics/literals/regex.html). you can find an example in `allow_list.txt.sample`.

```bash
cp allow_list.txt.sample allow_list.txt
ALLOW_LIST_FILE_PATH=allow_list.txt ./lightning_image
```

NOTE: if allow list file is not specified or empty, all URLs will be allowed.

## Boost 🚀

Check [`boost/`](./boost/) directory for more details.

## Development

dependencies:
- [crystal](https://crystal-lang.org/) >= 1.19.1
- [libvips](https://www.libvips.org/) >= 8.18.2

```bash
bin/setup
bin/dev
```

## by docker for development

```bash
bin/docker_dev
```

## run test

```bash
bin/test
```

## build binary for production

```bash
bin/build
bin/run
```

## build docker image for production

```bash
bin/docker_build
bin/docker_run
```

## Contributors

- [kibitan](https://github.com/kibitan) - creator and maintainer
