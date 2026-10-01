#!/bin/bash
# Copy this folder to the VM or paste the python file to /opt/omr first.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
RUN_USER="${SUDO_USER:-$(whoami)}"
sudo apt-get update
# tesseract-ocr and python3-pil read lyric lines again, one line at a time.
sudo apt-get install -y python3-flask xvfb tesseract-ocr python3-pil
sudo mkdir -p /opt/omr/jobs
sudo cp "$HERE/omr_server.py" /opt/omr/omr_server.py
for module in omr_score omr_rules omr_book omr_marks omr_text omr_validate omr_annotations omr_ai ai_verify; do
  sudo cp "$HERE/$module.py" "/opt/omr/$module.py"
done
sudo chmod 755 /opt/omr/omr_server.py
sudo chown -R "$RUN_USER:$RUN_USER" /opt/omr
sudo tee /etc/systemd/system/omr.service >/dev/null <<EOF
[Unit]
Description=Audiveris OMR convert API
After=network.target

[Service]
Type=simple
User=$RUN_USER
Environment=OMR_TOKEN=piano-omr-dev
Environment=OMR_JOBS=/opt/omr/jobs
Environment=JAVA_TOOL_OPTIONS=-Xmx4g
EnvironmentFile=-/etc/default/omr
WorkingDirectory=/opt/omr
ExecStart=/usr/bin/python3 /opt/omr/omr_server.py
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable --now omr.service
sudo systemctl --no-pager --full status omr.service
