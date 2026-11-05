#!/bin/bash
# Install your Python environment
apt-get update -y
apt-get install -y python3-venv git

# Clone the latest app directly onto the server
git clone https://github.com/owdeky017-ui/cad-w11-app.git /opt/cad-w11-app
cd /opt/cad-w11-app
python3 -m venv venv
venv/bin/pip install -r requirements.txt

# Run uvicorn as a systemd service, so it comes back up after a stop/start
cat > /etc/systemd/system/cad-app.service <<'UNIT'
[Unit]
Description=CAD W11 FastAPI app
After=network-online.target

[Service]
WorkingDirectory=/opt/cad-w11-app
ExecStart=/opt/cad-w11-app/venv/bin/uvicorn main:app --host 0.0.0.0 --port 80
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable --now cad-app.service
