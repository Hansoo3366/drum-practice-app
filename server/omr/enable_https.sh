#!/bin/bash
# Puts the worker behind HTTPS. Caddy answers on port 443 with a certificate
# it gets and renews by itself and passes requests on to the worker, which
# from then on listens on this machine only (plain http on 8080 is closed).
#
# Usage: sudo bash enable_https.sh <host-name>
#   <host-name> must already point at this VM: a domain's A record, or
#   a-b-c-d.sslip.io for the address a.b.c.d. Ports 80 and 443 must be open
#   in the cloud firewall (Google Cloud: "Allow HTTP/HTTPS traffic" on the VM).
#   KEEP_HTTP=1 leaves port 8080 open as well, while builds of the app that
#   still use it are around.
set -euo pipefail

HOST_NAME="${1:?host name, e.g. omr.example.com or 34-10-15-222.sslip.io}"
ENV_FILE=/etc/default/omr

if ! command -v caddy >/dev/null; then
  apt-get update
  apt-get install -y caddy
fi

# The upload limit is the worker's own (40 MB).
cat >/etc/caddy/Caddyfile <<EOF
$HOST_NAME {
	request_body {
		max_size 40MB
	}
	reverse_proxy 127.0.0.1:8080
}
EOF
caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile
systemctl enable caddy
systemctl restart caddy

if [ "${KEEP_HTTP:-0}" != "1" ]; then
  touch "$ENV_FILE"
  if grep -q '^OMR_HOST=' "$ENV_FILE"; then
    sed -i 's/^OMR_HOST=.*/OMR_HOST=127.0.0.1/' "$ENV_FILE"
  else
    echo 'OMR_HOST=127.0.0.1' >>"$ENV_FILE"
  fi
  systemctl restart omr.service
fi

echo "---- health over https ----"
# The first certificate takes a few seconds.
curl --fail --silent --show-error --retry 12 --retry-delay 5 --retry-all-errors \
  --max-time 15 "https://$HOST_NAME/health"
echo
echo "HTTPS OK: https://$HOST_NAME"
