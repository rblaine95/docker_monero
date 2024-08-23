###################
# --- builder --- #
###################
FROM docker.io/debian:12-slim AS builder

WORKDIR /opt

RUN apt-get update && \
    apt-get dist-upgrade -y && \
    apt-get install -y \
      wget ca-certificates bzip2

ARG MONERO_VERSION=v0.18.3.4
WORKDIR /opt/monero
RUN case "$(uname -m)" in \
      x86_64) ARCH="x64"; SHA256SUM="51ba03928d189c1c11b5379cab17dd9ae8d2230056dc05c872d0f8dba4a87f1d" ;; \
      aarch64* | arm64 | armv8*) ARCH="armv8"; SHA256SUM="33ca2f0055529d225b61314c56370e35606b40edad61c91c859f873ed67a1ea7" ;; \
      armv7*) ARCH="armv7"; SHA256SUM="354603c56446fb0551cdd6933bce5a13590b7881e05979b7ec25d89e7e59a0e2" ;; \
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
