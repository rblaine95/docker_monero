FROM ghcr.io/rblaine95/alpine:3.14 AS builder

# https://git.alpinelinux.org/aports/tree/testing/monero/APKBUILD
# https://github.com/alpinelinux/aports/blob/master/testing/monero/APKBUILD
ARG MONERO_VERSION=0.17.2.0

WORKDIR /opt

RUN apk update && \
    apk upgrade && \
    apk add boost boost-dev \
        cmake zeromq boost-chrono boost-filesystem \
        boost-program_options boost-regex boost-static \
        boost-serialization boost-thread boost-build \
        libsodium-dev miniupnpc-dev openssl-dev \
        openpgm-dev rapidjson-dev readline-dev \
        unbound-dev zeromq-dev git build-base && \
    apk add --repository http://dl-cdn.alpinelinux.org/alpine/edge/testing cppzmq

RUN git clone --recursive https://github.com/monero-project/monero.git -b v${MONERO_VERSION}

RUN mkdir -p monero/build && cd monero/build && \
    cmake -DCMAKE_INSTALL_PREFIX=/opt \
          -DSTATIC=ON \
          -DARCH="x86-64" \
          -DBUILD_64=ON \
          -DCMAKE_BUILD_TYPE=release \
          -DBUILD_TAG="linux-x64" \
          -DSTACK_TRACE:BOOL=OFF \
          -DMANUAL_SUBMODULES=1 \
          .. && \
    make -j2

FROM ghcr.io/rblaine95/alpine:3.14

ENV PATH=/opt/monero:${PATH}

RUN apk update && \
    apk --no-cache upgrade && \
    apk --no-cache add libgcc \
        boost-chrono boost-filesystem \
        boost-program_options libstdc++ \
        icu-libs boost-regex boost-serialization \
        boost-thread miniupnpc ncurses-terminfo-base \
        ncurses-libs readline libsodium libevent unbound-libs libzmq && \
    addgroup monero && \
    adduser -D -h /home/monero -s /bin/sh -G monero monero && \
    mkdir -p /home/monero/.bitmonero && \
    chown -R monero:monero /home/monero/.bitmonero
COPY --from=builder /opt/monero/build/bin/monero* /opt/monero/

USER monero

WORKDIR /home/monero

VOLUME /home/monero/.bitmonero

EXPOSE 18080 18081

ENTRYPOINT ["/opt/monero/monerod"]
