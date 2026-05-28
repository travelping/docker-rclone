FROM alpine:3.23.4 AS base

## build-stage

FROM base AS builder
RUN apk add --no-cache bash curl

ENV MISE_DATA_DIR=/mise \
    MISE_CONFIG_DIR=/mise \
    MISE_CACHE_DIR=/mise/cache \
    MISE_INSTALL_PATH=/usr/local/bin/mise \
    PATH=/usr/local/bin:/usr/bin:/bin

RUN curl -fsSL https://mise.run | sh

WORKDIR /work
COPY mise.container.toml ./mise.toml
COPY mise.container.lock ./mise.lock
RUN mise trust /work/mise.toml && \
    mise install "http:rclone" && \
    cp "$(mise where http:rclone)/rclone" /usr/bin/rclone && \
    chown root:root /usr/bin/rclone && \
    chmod 755 /usr/bin/rclone

##
## runtime-stage

FROM base

## supplied by the `mise run build` task (derived from mise.container.toml)
## or by docker/metadata-action in CI; default is a fallback for raw builds
ARG RCLONE_VERSION=1.74.2

## https://github.com/opencontainers/image-spec/blob/v1.1.1/annotations.md
LABEL org.opencontainers.image.url="https://github.com/travelping/docker-rclone"
LABEL org.opencontainers.image.source="https://github.com/travelping/docker-rclone"
LABEL org.opencontainers.image.version="${RCLONE_VERSION}"
LABEL org.opencontainers.image.vendor="Travelping GmbH"
LABEL org.opencontainers.image.title="rclone-${RCLONE_VERSION}"
LABEL org.opencontainers.image.description="rclone - rsync for cloud storage"

RUN apk update && apk upgrade --no-cache && apk --no-cache add \
    ca-certificates \
    coreutils \
    inotify-tools \
    lz4 zstd
COPY --from=builder /usr/bin/rclone /usr/bin/rclone

ENTRYPOINT ["/usr/bin/rclone"]
