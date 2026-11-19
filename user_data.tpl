#!/bin/bash
# Install your Python environment
apt-get update -y
apt-get install -y python3-venv git

# Clone the latest app directly onto the server
git clone https://github.com/owdeky017-ui/cad-w11-app.git /opt/cad-w11-app
cd /opt/cad-w11-app
python3 -m venv venv
venv/bin/pip install -r requirements.txt

# Connection string for the RDS PostgreSQL database
cat > /etc/cad-app.env <<'ENVFILE'
DATABASE_URL="postgresql+psycopg2://${db_user}:${db_pwd}@${db_host}:${db_port}"
ENVFILE

# Run uvicorn as a systemd service, so it comes back up after a stop/start
cat > /etc/systemd/system/cad-app.service <<'UNIT'
[Unit]
Description=CAD W11 FastAPI app
After=network-online.target
Wants=network-online.target
StartLimitIntervalSec=0

[Service]
WorkingDirectory=/opt/cad-w11-app
EnvironmentFile=/etc/cad-app.env
ExecStart=/opt/cad-w11-app/venv/bin/uvicorn main:app --host 0.0.0.0 --port ${app_port}
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable --now cad-app.service
