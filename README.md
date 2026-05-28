# docker-rclone

Container image bundling [`rclone`](https://rclone.org/) with `inotify-tools`,
`lz4` and `zstd`. The intended use is unattended, environment-driven moves of
freshly-written files to remote storage (SFTP, S3, OneDrive, …), optionally
compressing them on the way out.

Configuration is taken entirely from environment variables — no config file
is mounted. Any rclone long option becomes an environment variable by
stripping the leading `--`, replacing `-` with `_`, upper-casing it and
prepending `RCLONE_`. See the [rclone command reference](https://rclone.org/commands/)
for the available options per command.

## Usage

### Run `rclone` (default entrypoint)

```bash
docker run --rm -it travelping/docker-rclone:latest --help
```

### Run `rclone` (SFTP)

Touch a file on a remote SFTP server using only environment configuration:

```bash
docker run --rm -it \
  -e RCLONE_CONFIG_SFTP_TYPE=sftp \
  -e RCLONE_CONFIG_SFTP_HOST=host.com \
  -e RCLONE_CONFIG_SFTP_USER=name \
  -e RCLONE_CONFIG_SFTP_PORT=23 \
  -e RCLONE_CONFIG_SFTP_PASS=password \
  travelping/docker-rclone:latest touch sftp:path
```

### Run `rclone` (S3)

```bash
docker run --rm -it \
  -e RCLONE_CONFIG_S3_TYPE=s3 \
  -e RCLONE_CONFIG_S3_ENV_AUTH=false \
  -e RCLONE_CONFIG_S3_ACCESS_KEY_ID=<sensitive> \
  -e RCLONE_CONFIG_S3_SECRET_ACCESS_KEY=<sensitive> \
  -e RCLONE_CONFIG_S3_REGION=s3-<region> \
  -e RCLONE_CONFIG_S3_ACL=private \
  -e RCLONE_CONFIG_S3_FORCE_PATH_STYLE=false \
  travelping/docker-rclone:latest touch s3:path
```

### Run a shell

```bash
docker run --rm -it --entrypoint=/bin/sh travelping/docker-rclone:latest
```

## Inotify patterns

The image also ships `inotify-tools`. Watch patterns can ensure only fully
written files are transferred — avoiding garbage data being moved mid-write
(for example, traces still being captured).

Log every inotify event for `/data/`:

```bash
inotifywait -mr --timefmt '%H:%M' --format '%T %w %e %f' /data/
```

### Move on `close_write`

Push only finished data to the destination:

```bash
watchnames=''
[ -d /data/ ] && watchnames="$watchnames /data/"
inotifywait --monitor -e close_write --format %w%f $watchnames | while read FILE
do
  echo "$FILE is finished. Moving to data/finished/"
  mv "$FILE" data/finished/
  rclone move /data/finished/ "$RCLONE_REMOTE_NAME:$RCLONE_REMOTE_PATH/"
done
```

### Move with lz4 compression

Like the previous example, but compress with lz4 before push:

```bash
watchnames=''
[ -d /data/ ] && watchnames="$watchnames /data/"
inotifywait --monitor -e close_write --format %w%f $watchnames | while read FILE
do
  echo "$FILE is finished. Moving to data/finished/"
  lz4 --rm -c9 "$FILE" > "data/finished/$(basename "$FILE").lz4"
  rclone move /data/finished/ "$RCLONE_REMOTE_NAME:$RCLONE_REMOTE_PATH/"
done
```

### Move with zstd compression

Compresses better than lz4 but uses more CPU — pick your poison:

```bash
watchnames=''
[ -d /data/ ] && watchnames="$watchnames /data/"
inotifywait --monitor -e close_write --format %w%f $watchnames | while read FILE
do
  echo "$FILE is finished. Moving to data/finished/"
  zstd --rm -19 "$FILE" -o "data/finished/$(basename "$FILE").zst"
  rclone move /data/finished/ "$RCLONE_REMOTE_NAME:$RCLONE_REMOTE_PATH/"
done
```

## Build

The rclone version is pinned in [`mise.container.toml`](./mise.container.toml).
To bump it, edit that file (and refresh `mise.container.lock` with
`MISE_ENV=container mise lock`), then build:

```bash
docker build -t docker-rclone .
```

Or via the bundled mise task (uses `podman` by default; pass `-e docker` to
use Docker):

```bash
mise run build              # podman build
mise run build -- -e docker # docker build
```
