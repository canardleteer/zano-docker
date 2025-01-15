# `zano-docker`

A quick docker image for [Zano](https://zano.org/), cloning directly from
[`hyle-team/zano` on GitHub](https://github.com/hyle-team/zano).

Could use more cleanup, which I get to here and there.

I have no Zano, you're welcome to tip me so I have some:
`ZxCizQz5yN7Bi8smVVkHLLhLf4rRgiiwca77LsRCvKE1DhJGPmZ9vva3vsGgFQaTu4gj4XaDj4PVghdQ2pnTp9Lh2EVm7WnhA`

## Dockerhub

CI publishes the image here:
[https://hub.docker.com/r/canardleteer/zano](https://hub.docker.com/r/canardleteer/zano)
, and you can use those in the examples below.

## Building the simple to use `zanod` + `simplewallet` Image

```shell
# To build the latest Zano from the master branch with 1 core
docker build -t zano:latest .

# To build Zano 2.0.1.367 with all processors on your system.
docker build \
    --build-arg ZANO_REF="2.0.1.367" \
    --build-arg BUILD_WIDTH=$(nproc) \
    -t zano-runner:latest .

# To build a distroless zanod from Zano 2.0.1.367 with all processors on
# your system.
docker build \
    --build-arg ZANO_REF="2.0.1.367" \
    --build-arg BUILD_WIDTH=$(nproc) \
    --target=zanod-distroless \
    -t zanod-distroless:latest .

# To build a distroless simplewallet from Zano 2.0.1.367 with all processors
# on your system.
docker build \
    --build-arg ZANO_REF="2.0.1.367" \
    --build-arg BUILD_WIDTH=$(nproc) \
    --target=simplewallet-distroless \
    -t simplewallet-distroless:latest .
```

Additional `ARG`'s are documented inline in the `Dockerfile`.

## Multistage & Differences

- Building is done on an Ubuntu 22.04 image by default.
- `zano-runner` is built by default, which is based on Ubuntu 24.04 also by
  default.
  - Username is `ubuntu`, with `/home/ubuntu` as `$HOME`
- `zanod-distroless` is a nonroot distroless Debian 12 image, with just
  `zanod`.
  - Username is `nonroot`, with user id `65532`, and `/home/nonroot` as `$HOME`
- `simplewallet-distroless` is a nonroot distroless Debian 12 image with just
  `simplewallet`.
  - Username is `nonroot`, with user id `65532`, and `/home/nonroot` as `$HOME`

If you wish to shuffle around mount points and directories, you can do so with
the CLI arguments of `zanod` and `simplewallet`. I just want to make sure
there's no confusion, since `zanod` assumes a ${HOME} for data, and there may
be intermingling of user IDs in the directories if you're running locally.

## Github Actions

Github Actions build and push these to Dockerhub. **It is highly advisable that
you build and host your own images instead of using these.** I can promise that
as a user of Github, I'm being transparent by publishing the logs. I cannot
promise that the actions taken by Github within their own backend are
transparent.

I will probably change the Dockerhub label strategy, and make these Actions a
`strategy.matrix` at some point.

## Usage Of `zano-runner`

- **I use a local directory for local development, others may choose a more pure
volume.**

```shell
# "zano-data" - keeps state of the chain, which you may or may not want.
# "private"   - is meant as a place for you to keep a wallet file, it is the
#               responsibility of the container operator, to ensure it is, if
#               it is used.
mkdir -p {zano-data,private}

# Run the daemon with persistent storage in a local directory.
#
# NOTE: `-t` is required, the Zano daemon requires a tty.
docker run -td --name zano-runner -v ${PWD}/zano-data:/home/ubuntu/.Zano -v ${PWD}/private:/home/ubuntu/private -p 11121:11121 -p 11211:11211 zano-runner:latest

# Tail logs
docker logs -f zano-runner

# Enter the running container with bash or do some simplewallet commands
docker exec -it zano-runner /bin/bash
docker exec -it zano-runner /usr/bin/simplewallet --help
docker exec -it zano-runner /usr/bin/simplewallet --generate-new-wallet=private/test-wallet
docker exec -it zano-runner /usr/bin/simplewallet --wallet=private/test-wallet
docker exec -it zano-runner /usr/bin/simplewallet --wallet=private/test-wallet --command wallet_bc_height

# Stop and remove the container, preserving data for the next run.
# Alternatively, you can use "run --rm" if you don't keep it around for debugging.
docker stop zano-runner
docker rm zano-runner
```

## Usage Of `zanod-distroless`

```shell
mkdir -p zano-data

# WARNING(canarleteer): If you intend to "re-use" a zano chain from the
#                       "zano-runner" image, you'll need to do a:
#
#                       chmod -R oug+rwx zano-data
#
#                       So that "nonroot" can read and write here, but
#                       I don't recommend doing it at all.
docker run -td --name zanod -v ${PWD}/zano-data:/home/nonroot/.Zano -p 11121:11121 -p 11211:11211 zanod-distroless:latest
docker logs zanod

# Stop and remove the container, preserving data for the next run.
# Alternatively, you can use "run --rm" if you don't keep it around for debugging.
docker stop zanod
docker rm zanod
```

## Usage Of `zanod-distroless`

```shell
mkdir -p private

# WARNING(canardleteer): I really don't recommend sharing this `private`
#                       directory between a `zano-runner` container, and a
#                       `simplewallet-distroless` container. If you decide too,
#                       you'll need to wire up permissions similar to
#                       zanod-distroless.

docker run -it --name simplewallet -v ${PWD}/private:/home/nonroot/private simplewallet-distroless:latest --generate-new-wallet=private/distroless-wallet
docker rm simplewallet

# WARNING(canardleteer): The "docker attach" workflow is suboptimal, this
#                        container should really only be used with more
#                        supporting container infrastructure to connect
#                        to zanod, but is shown here as a demo.
docker run -itd --name simplewallet -v ${PWD}/private:/home/nonroot/private simplewallet-distroless:latest --wallet=private/distroless-wallet
docker attach simplewallet
# [enter password for wallet, you won't see the prompt]

# Alternatively, you can use "run --rm" if you don't keep it around for debugging.
docker stop simplewallet
docker rm simplewallet
```