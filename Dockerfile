###################
# --- builder --- #
###################
FROM docker.io/debian:12-slim AS builder

WORKDIR /opt

RUN apt-get update && \
    apt-get dist-upgrade -y && \
    apt-get install -y \
      wget ca-certificates bzip2

ARG MONERO_VERSION=v0.18.3.2
WORKDIR /opt/monero
RUN case "$(uname -m)" in \
      x86_64) ARCH="x64"; SHA256SUM="9dafd70230a7b3a73101b624f3b5f439cc5b84a19b12c17c24e6aab94b678cbb" ;; \
      aarch64* | arm64 | armv8*) ARCH="armv8"; SHA256SUM="72f5c90955a736d99c1a645850984535050ebddd42c39a27eec1df82bd972126" ;; \
      armv7*) ARCH="armv7"; SHA256SUM="5df3a1390960c1632c797b8dfb46e93ebb2e93498e4e5e517be0bda6ff5b719b" ;; \
      *) echo "Unexpected architecture: $(uname -m)" && exit 1;; \
    esac \
    \
    && wget https://downloads.getmonero.org/cli/monero-linux-${ARCH}-${MONERO_VERSION}.tar.bz2 \
    && echo "${SHA256SUM}  monero-linux-${ARCH}-${MONERO_VERSION}.tar.bz2" | sha256sum -c \
    && tar -xjvf monero-linux-${ARCH}-${MONERO_VERSION}.tar.bz2 --strip-components 1 \
    && rm -f monero-linux-${ARCH}-${MONERO_VERSION}.tar.bz2

##################
# -- exporter -- #
##################
FROM docker.io/golang:1.22 AS exporter

RUN GO111MODULE=on go install github.com/cirocosta/monero-exporter/cmd/monero-exporter@master

##################
# --- runner --- #
##################
FROM docker.io/debian:12-slim AS runner

ENV PATH=/opt/monero:${PATH}

RUN apt-get update && \
    apt-get dist-upgrade -y && \
    apt-get install -y tini ca-certificates && \
    apt-get clean && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt && \
    useradd -ms /bin/bash monero && \
    mkdir /opt/bitmonero && \
    ln -s /opt/bitmonero /home/monero/.bitmonero && \
    chown -R monero:monero /home/monero/.bitmonero && \
    chown -R monero:monero /opt/bitmonero

COPY --from=builder /opt/monero/* /opt/monero/
COPY --from=exporter /go/bin/monero-exporter /opt/monero/monero-exporter
COPY ./entrypoint.sh /entrypoint.sh

USER monero
WORKDIR /home/monero
VOLUME /opt/bitmonero
EXPOSE 18080 18081

ENTRYPOINT ["tini", "--", "/entrypoint.sh"]
