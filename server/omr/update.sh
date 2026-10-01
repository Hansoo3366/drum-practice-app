#!/bin/bash
# Upload this script, omr_server.py and its omr_*.py modules to the same VM
# directory, then run it.
# Usage: bash /root/update.sh [upload-directory]
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
UPLOAD_DIR="${1:-$SCRIPT_DIR}"
SERVER_SRC="$UPLOAD_DIR/omr_server.py"
COMPARE_SRC="$UPLOAD_DIR/compare_musicxml.py"
AI_SRC="$UPLOAD_DIR/ai_verify.py"
# The server's modules; every one is required.
MODULES=(omr_score omr_rules omr_book omr_marks omr_text omr_validate omr_ai)

if [ ! -f "$SERVER_SRC" ]; then
  echo "omr_server.py not found in upload directory: $UPLOAD_DIR" >&2
  exit 1
fi
for module in "${MODULES[@]}"; do
  if [ ! -f "$UPLOAD_DIR/$module.py" ]; then
    echo "$module.py not found in upload directory: $UPLOAD_DIR" >&2
    exit 1
  fi
done
if ! grep -q 'def job_status' "$SERVER_SRC" || ! grep -q 'pdf-multipass-v1' "$UPLOAD_DIR/omr_score.py"; then
  echo "omr_server.py is not the current OMR server version: $SERVER_SRC" >&2
  exit 1
fi

# Parse before replacing the live service; this does not write into the upload directory.
for source in "$SERVER_SRC" "${MODULES[@]/#/$UPLOAD_DIR/}"; do
  source="${source%.py}.py"
  python3 -c 'import ast, pathlib, sys; ast.parse(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))' "$source"
done
if [ -f "$COMPARE_SRC" ]; then
  python3 -c 'import ast, pathlib, sys; ast.parse(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))' "$COMPARE_SRC"
fi

sudo install -d -m 755 /opt/omr
for module in "${MODULES[@]}"; do
  sudo install -m 644 "$UPLOAD_DIR/$module.py" "/opt/omr/$module.py"
done
sudo install -m 755 "$SERVER_SRC" /opt/omr/omr_server.py
if [ -f "$AI_SRC" ]; then
  python3 -c 'import ast, pathlib, sys; ast.parse(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))' "$AI_SRC"
  sudo install -m 644 "$AI_SRC" /opt/omr/ai_verify.py
  echo "AI review client installed."
fi
if [ -f "$COMPARE_SRC" ]; then
  sudo install -m 755 "$COMPARE_SRC" /opt/omr/compare_musicxml.py
  echo "Optional comparison tool installed."
else
  echo "No compare_musicxml.py in $UPLOAD_DIR; conversion does not need it."
fi

# Existing installs can read optional OCR/DPI configuration without re-running install.sh.
sudo install -d -m 755 /etc/systemd/system/omr.service.d
printf '%s\n' '[Service]' 'EnvironmentFile=-/etc/default/omr' | \
  sudo tee /etc/systemd/system/omr.service.d/10-omr-environment.conf >/dev/null
sudo systemctl daemon-reload
sudo systemctl restart omr.service
sudo systemctl is-active --quiet omr.service
echo "---- health ----"
HEALTH="$(curl --fail --silent --show-error --retry 5 --retry-delay 1 --retry-connrefused \
  --max-time 10 http://127.0.0.1:8080/health)"
echo "$HEALTH"
python3 -c 'import json, sys; data=json.loads(sys.argv[1]); sys.exit(0 if data.get("ok") is True and data.get("pipeline") == "pdf-multipass-v1" else "Unexpected pipeline; check the service ExecStart")' "$HEALTH"
echo "OMR update OK"
