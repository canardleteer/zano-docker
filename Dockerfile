# NOTE(canardleteer): Generally just the instructions from the upstream repo
#                     to build, I'm sure that can be optimized, but I haven't
#                     taken the time to do so.

# NOTE(canardleteer): I haven't tested beyond ubuntu:22, but you're welcome
#                     to experiment with a different base image. Feel free to
#                     contribute findings or necessary adjustments needed to
#                     make it more flexable.
ARG UBUNTU_VERSION=22.04

FROM ubuntu:${UBUNTU_VERSION} AS builder

# Zano Repository Reference
ARG ZANO_REF=master

# Argument to pass to `make -j` & `git clone -j`
ARG BUILD_WIDTH=1

RUN apt update && \
    apt install -y git curl build-essential g++ curl autotools-dev libicu-dev libbz2-dev cmake git screen checkinstall zlib1g-dev && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /zano

RUN git clone --branch ${ZANO_REF} -j${BUILD_WIDTH} --recursive https://github.com/hyle-team/zano.git

RUN curl -OL https://boostorg.jfrog.io/artifactory/main/release/1.84.0/source/boost_1_84_0.tar.bz2 && \
    echo "cc4b893acf645c9d4b698e9a0f08ca8846aa5d6c68275c14c3e7949c24109454  boost_1_84_0.tar.bz2" | shasum -c && \
    tar -xjf boost_1_84_0.tar.bz2 && mv boost_1_84_0 boost && \
    rm boost_1_84_0.tar.bz2 && cd boost && \
    ./bootstrap.sh --with-libraries=system,filesystem,thread,date_time,chrono,regex,serialization,atomic,program_options,locale,timer,log && \
    ./b2 && cd ..

RUN curl -OL https://www.openssl.org/source/openssl-1.1.1w.tar.gz && \
    echo "cf3098950cb4d853ad95c0841f1f9c6d3dc102dccfcacd521d93925208b76ac8  openssl-1.1.1w.tar.gz" | shasum -c && tar xaf openssl-1.1.1w.tar.gz && \
    cd openssl-1.1.1w && \
    ./config --prefix=/zano/openssl --openssldir=/zano/openssl shared zlib && \
    make && make test && make install && cd ..

ENV BOOST_ROOT=/zano/boost
ENV OPENSSL_ROOT_DIR=/zano/openssl

RUN cd zano && mkdir build && cd build && \
    cmake .. && \
    make -j${BUILD_WIDTH} daemon simplewallet && cd ..

FROM ubuntu:${UBUNTU_VERSION} AS runner

WORKDIR /zano

# NOTE(canardleteer): This hasn't been tuned much, I'm sure it can be tuned
#                     better by specifying a specific version without `-dev`,
#                     but it's Ubuntu version specific.
RUN apt update && \
    apt install -y libicu-dev && \
    rm -rf /var/lib/apt/lists/*

RUN useradd -ms /bin/bash zano && \
    mkdir /home/zano/.Zano && \
    chown zano:zano /home/zano/.Zano

# NOTE(canardleteer): Blind copy here, boost should probably be cleaned up.
COPY --from=builder /zano/openssl /zano/openssl 
COPY --from=builder /zano/boost /zano/boost
COPY --from=builder /zano/zano/build/src/simplewallet /usr/bin/simplewallet
COPY --from=builder /zano/zano/build/src/zanod /usr/bin/zanod
COPY ./zanod-startup.sh /usr/bin/zanod-startup.sh

USER zano
WORKDIR /home/zano

ENTRYPOINT [ "/usr/bin/zanod-startup.sh" ]
