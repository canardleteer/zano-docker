# `zano-docker`

A quick docker image for [Zano](https://zano.org/), cloning directly from [`hyle-team/zano` on GitHub](https://github.com/hyle-team/zano).

Could use some cleanup, which I'll maybe get to over time.

I have no Zano, you're welcome to tip me so I have some: `ZxCizQz5yN7Bi8smVVkHLLhLf4rRgiiwca77LsRCvKE1DhJGPmZ9vva3vsGgFQaTu4gj4XaDj4PVghdQ2pnTp9Lh2EVm7WnhA`

## Dockerhub

CI publishes the image here: [https://hub.docker.com/r/canardleteer/zano](https://hub.docker.com/r/canardleteer/zano)

## Building the `zanod` + `simplewallet` Image

```shell
# To build the latest Zano from the master branch with 1 core
docker build -t zano:latest .

# To build Zano 2.0.1.367 with all processors on your system.
docker build \
    --build-arg ZANO_REF="2.0.1.367" \
    --build-arg BUILD_WIDTH=$(nproc) \
    -t zano:latest .
```

Additional `ARG`'s are documented inline in the `Dockerfile`.

## Usage

- If you don't want to build it locally, it's [available on dockerhub as `canardleteer/zano`](https://hub.docker.com/r/canardleteer/zano).
  Just replace the image name `zano:latest` with `canardleteer/zano:sometag` below.
  - I do recommend building and hosting your own image.

```shell
# "zano-data" - keeps state of the chain, which you may or may not want.
# "private"   - is meant as a place for you to keep a wallet file, it is the
#               responsibility of the container operator, to ensure it is, if
#               it is used.
mkdir -p {zano-data,private}

# Run the daemon with persistent storage in a local directory.
#
# NOTE: `-t` is required, the Zano daemon requires a tty.
docker run -td --name zano -v ${PWD}/zano-data:/home/zano/.Zano -v ${PWD}/private:/home/zano/private -p 11121:11121 -p 11211:11211 zano:latest

# Tail logs
docker logs -f zano

# Enter the running container with bash or do some simplewallet commands
docker exec -it zano /bin/bash
docker exec -it zano /usr/bin/simplewallet --help
docker exec -it zano /usr/bin/simplewallet --generate-new-wallet=private/test-wallet
docker exec -it zano /usr/bin/simplewallet --wallet=private/test-wallet
docker exec -it zano /usr/bin/simplewallet --wallet=private/test-wallet --command wallet_bc_height

# Stop and remove the container, preserving data for the next run.
docker stop zano
docker rm zano
```
