FROM alpine:3.23.3 as base

## build-stage

FROM base as builder
ARG VERSION=v1.73.1
ARG SHA256=e9bad0be2ed85128e0d977bf36c165dd474a705ea950d18e1005cef98119407b

ADD --checksum="sha256:$SHA256" https://github.com/rclone/rclone/releases/download/$VERSION/rclone-$VERSION-linux-amd64.zip /tmp/rclone.zip
WORKDIR /tmp
RUN unzip -d . rclone.zip "**/rclone" && \
    find . -name "rclone" -type f -exec cp {} /usr/bin ';' && \
    chown root:root /usr/bin/rclone && \
    chmod 755 /usr/bin/rclone

##
## runtime-stage

FROM base

ARG VERSION=v1.73.1

## https://github.com/opencontainers/image-spec/releases/tag/v1.0.1
LABEL org.opencontainers.image.url="https://github.com/travelping/docker-rclone"
LABEL org.opencontainers.image.source="https://github.com/travelping/docker-rclone"
LABEL org.opencontainers.image.version=$VERSION
LABEL org.opencontainers.image.vendor="Travelping GmbH"
LABEL org.opencontainers.image.title="rclone-$VERSION"
LABEL org.opencontainers.image.description="rclone - rsync for cloud storage"

RUN apk update && apk upgrade --no-cache && apk --no-cache add \
    ca-certificates \
    coreutils \
    inotify-tools \
    lz4 zstd
COPY --from=builder /usr/bin/rclone /usr/bin/rclone

ENTRYPOINT ["/usr/bin/rclone"]
