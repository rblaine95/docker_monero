###################
# --- builder --- #
###################
FROM docker.io/debian:12-slim AS builder

WORKDIR /opt

RUN apt-get update && \
    apt-get dist-upgrade -y && \
    apt-get install -y \
      wget ca-certificates bzip2

ARG MONERO_VERSION=v0.18.3.3
WORKDIR /opt/monero
RUN case "$(uname -m)" in \
      x86_64) ARCH="x64"; SHA256SUM="47c7e6b4b88a57205800a2538065a7874174cd087eedc2526bee1ebcce0cc5e3" ;; \
      aarch64* | arm64 | armv8*) ARCH="armv8"; SHA256SUM="eb3f924c085ae5df85f5bf9ee27faaa20acd309835684e27e3fbb98b9666b649" ;; \
      armv7*) ARCH="armv7"; SHA256SUM="f3f982b141cb6c88939d15a83aaa26334d628c0d2766d6834371030dd00401d3" ;; \
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
