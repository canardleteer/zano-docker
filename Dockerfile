# NOTE(canardleteer): I haven't tested building beyond ubuntu:22 for building,
#                     but you're welcome to experiment with a different base
#                     image. Feel free to contribute findings or necessary
#                     adjustments needed to make it more flexable.
ARG UBUNTU_BUILDER_VERSION=22.04
ARG UBUNTU_RUNNER_VERSION=24.04

FROM ubuntu:${UBUNTU_BUILDER_VERSION} AS builder

# Zano Repository Reference
ARG ZANO_REF=master
ARG ZANO_REPO="https://github.com/hyle-team/zano.git"

# Argument to pass to `make -j` & `git clone -j`.
ARG BUILD_WIDTH=1

# Boost Build Configuration
ARG BOOST_HASH=cc4b893acf645c9d4b698e9a0f08ca8846aa5d6c68275c14c3e7949c24109454
ARG BOOST_VERSION=1.84.0

# OpenSSL Build Configuration
ARG OPENSSL_HASH=cf3098950cb4d853ad95c0841f1f9c6d3dc102dccfcacd521d93925208b76ac8
ARG OPENSSL_VERSION=1.1.1w

ENV DEBIAN_FRONTEND=noninteractive
RUN apt update && \
    apt install -y git curl build-essential g++ curl autotools-dev libicu-dev libbz2-dev cmake git screen checkinstall zlib1g-dev && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /zano

# Download and layout required sources
RUN set -ex && export BOOST_VERSION_UNDER="$(echo ${BOOST_VERSION} | sed 's/\./_/g')" && \
    curl -OL https://downloads.sourceforge.net/project/boost/boost/${BOOST_VERSION}/boost_${BOOST_VERSION_UNDER}.tar.bz2 && \
    echo "${BOOST_HASH}  boost_${BOOST_VERSION_UNDER}.tar.bz2" | shasum -c && \
    tar -xjf boost_${BOOST_VERSION_UNDER}.tar.bz2 && mv boost_${BOOST_VERSION_UNDER} boost && \
    rm boost_${BOOST_VERSION_UNDER}.tar.bz2

RUN curl -OL https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz && \
    echo "${OPENSSL_HASH}  openssl-${OPENSSL_VERSION}.tar.gz" | shasum -c && \
    tar xaf openssl-${OPENSSL_VERSION}.tar.gz && \
    rm openssl-${OPENSSL_VERSION}.tar.gz

RUN git clone --branch ${ZANO_REF} -j${BUILD_WIDTH} --single-branch --recursive ${ZANO_REPO}

# Build Libs
RUN cd boost && \
    ./bootstrap.sh --with-libraries=system,filesystem,thread,date_time,chrono,regex,serialization,atomic,program_options,locale,timer,log && \
    ./b2 && cd ..

RUN cd openssl-${OPENSSL_VERSION} && \
    ./config --prefix=/zano/openssl --openssldir=/zano/openssl shared zlib && \
    make && make test && make install && cd ..

ENV BOOST_ROOT=/zano/boost
ENV OPENSSL_ROOT_DIR=/zano/openssl

# Build Zano
RUN cd zano && mkdir build && cd build && \
    cmake -D STATIC=TRUE .. && \
    make -j${BUILD_WIDTH} daemon simplewallet && cd ..

###############################################################################
# simplewallet-distroless
FROM gcr.io/distroless/cc-debian12:nonroot AS simplewallet-distroless
COPY --from=builder /zano/zano/build/src/simplewallet /usr/bin/simplewallet
VOLUME [ "/home/nonroot/private" ]
ENTRYPOINT [ "/usr/bin/simplewallet" ]

###############################################################################
# zanod-distroless
FROM gcr.io/distroless/cc-debian12:nonroot AS zanod-distroless
COPY --from=builder /zano/zano/build/src/zanod /usr/bin/zanod
EXPOSE 11121 11211
VOLUME [ "/home/nonroot/.Zano" ]
ENTRYPOINT [ "/usr/bin/zanod" ]

###############################################################################
# zano-runner is a much less restricted container image.
FROM ubuntu:${UBUNTU_RUNNER_VERSION} AS zano-runner

WORKDIR /zano

# NOTE(canardleteer): This hasn't been tuned much, I'm sure it can be tuned
#                     better by specifying a specific version without `-dev`,
#                     but it's Ubuntu version specific.
ENV DEBIAN_FRONTEND=noninteractive
RUN apt update && \
    apt install -y libicu-dev && \
    rm -rf /var/lib/apt/lists/*

# RUN useradd -ms /bin/bash zano && \
#     mkdir /home/zano/.Zano /home/zano/private && \
#     chown zano:zano /home/zano/.Zano /home/zano/private && \
#     chmod og-rwx /home/zano/.Zano /home/zano/private
RUN mkdir /home/ubuntu/.Zano /home/ubuntu/private && \
    chown ubuntu:ubuntu /home/ubuntu/.Zano /home/ubuntu/private && \
    chmod og-rwx /home/ubuntu/.Zano /home/ubuntu/private


COPY --from=builder /zano/zano/build/src/simplewallet /usr/bin/simplewallet
COPY --from=builder /zano/zano/build/src/zanod /usr/bin/zanod
COPY ./include/zanod-startup.sh /usr/bin/zanod-startup.sh

USER ubuntu
WORKDIR /home/ubuntu

# NOTE(canardleteer): Upstream, there is a port 33340 exposed, but it's used
#                     for a container internal nginx. I'm going to go a
#                     different way.
EXPOSE 11121 11211

# NOTE(canardleteer): It is expected, that the container's host, will be
#                     responsible for ensuring the privacy of "private".
#                     It is labeled "private" for the purposes of pointing a
#                     user running it, towards what they should do.
VOLUME [ "/home/ubuntu/.Zano" , "/home/ubuntu/private" ]

ENTRYPOINT [ "/usr/bin/zanod-startup.sh" ]
