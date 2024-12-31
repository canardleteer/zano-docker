# `zano-docker`

A quick docker image for [Zano](https://zano.org/).

Could use some cleanup, which I'll maybe get to over time.

I haven't added any `EXPOSE` hints (yet), so if you want to expose ports,
you'll want to do so with `-p`.

## Building

```shell
# To build the latest Zano from the master branch with 1 core
docker build -t zano:latest .

# To build Zano 2.0.1.367 with all processors on your system.
docker build \
    --build-arg ZANO_REF="2.0.1.367" \
    --build-arg BUILD_WIDTH=$(nproc --all) \
    -t zano:latest .
```

## Usage

```shell
# This currently keeps state of "everything," which you may or may not want.
mkdir -p zano-data

# Run the daemon with persistent storage in a local directory.
#
# NOTE: `-t` is required, the Zano daemon requires a tty.
docker run -td --name zano -v ${PWD}/zano-data:/home/zano/.Zano zano:latest

# Tail logs
docker logs -f zano

# Enter the running container with bash or do some simplewallet commands
docker exec -it zano /bin/bash
docker exec -it zano /usr/bin/simplewallet --help

# Stop and remove the container, preserving data for the next run.
docker stop zano
docker rm zano
```
