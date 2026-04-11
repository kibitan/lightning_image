ARG CRYSTAL_VERSION=1.19

FROM crystallang/crystal:${CRYSTAL_VERSION}-alpine AS builder
RUN apk --update --no-cache add vips-dev
WORKDIR /app/
COPY ./shard.yml ./shard.lock /app/
RUN shards install --production
COPY ./ /app/
RUN shards build --release

# base alpine image: https://github.com/crystal-lang/distribution-scripts/blob/master/docker/alpine.Dockerfile#L1C30-L1C34
FROM alpine:3.22
RUN apk --update --no-cache add gc vips
COPY --from=builder ./app/bin/lightning_image ./lightning_image
CMD ["./lightning_image"]
