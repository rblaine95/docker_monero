#!/bin/bash

if [ "${EXPORTER_ENABLED:-"true"}" = "true" ]; then
  /opt/monero/monero-exporter \
    --bind-addr "${EXPORTER_BIND:-":9000"}" \
    --monero-addr "http://127.0.0.1:18081" \
    --telemetry-path "${EXPORTER_PATH:-"/metrics"}" &
fi

/opt/monero/monerod "$@"

