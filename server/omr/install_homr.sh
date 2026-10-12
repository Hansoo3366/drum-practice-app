#!/bin/bash
# Installs homr, the second reader that gives lead sheets their bars and notes
# (omr_hybrid.py), in its own Python environment, and switches it on.
#
#   bash install_homr.sh            install and switch on
#   bash install_homr.sh --off      switch off again (the environment stays)
#
# homr is a separate program under AGPL-3.0 (https://github.com/liebharc/homr), run as it
# is published. It needs about 1.5 GB of disk (onnxruntime, OpenCV and its models) and
# reads a page in tens of seconds on the processor; no graphics card is used.
set -euo pipefail
HOMR_HOME="${HOMR_HOME:-/opt/omr/homr}"
HOMR_VERSION="${HOMR_VERSION:-0.7.0}"
DEFAULTS=/etc/default/omr

set_default() {
  # One line per name in the service's environment file; other lines stay as they are.
  sudo touch "$DEFAULTS"
  sudo sed -i "/^$1=/d" "$DEFAULTS"
  echo "$1=$2" | sudo tee -a "$DEFAULTS" >/dev/null
}

if [ "${1:-}" = "--off" ]; then
  set_default OMR_HYBRID_NOTES 0
  sudo systemctl restart omr.service
  echo "Second reader off."
  exit 0
fi

SERVICE_USER="$(systemctl show -p User --value omr.service 2>/dev/null || true)"
SERVICE_USER="${SERVICE_USER:-$(whoami)}"
sudo apt-get update
sudo apt-get install -y python3-venv libgl1 libglib2.0-0
sudo install -d -m 755 -o "$SERVICE_USER" "$HOMR_HOME"
sudo -u "$SERVICE_USER" python3 -m venv "$HOMR_HOME"
sudo -u "$SERVICE_USER" "$HOMR_HOME/bin/pip" install --quiet --upgrade pip
sudo -u "$SERVICE_USER" "$HOMR_HOME/bin/pip" install --quiet "homr==$HOMR_VERSION"
# Fetch the models now, not during the first conversion.
sudo -u "$SERVICE_USER" "$HOMR_HOME/bin/homr" --init --gpu no
[ -f /opt/omr/homr_sheet.py ] || { echo "/opt/omr/homr_sheet.py is missing: run update.sh first" >&2; exit 1; }

set_default OMR_HOMR_PYTHON "$HOMR_HOME/bin/python"
set_default OMR_HYBRID_NOTES 1
sudo systemctl restart omr.service
sudo systemctl is-active --quiet omr.service
echo "Second reader on: OMR_HOMR_PYTHON=$HOMR_HOME/bin/python"
