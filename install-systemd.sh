#!/bin/bash
# Installation script for systemd services (non-Docker deployment)

set -e

INSTALL_DIR="/opt/GenAI-Stack"
APP_USER="genai"
APP_GROUP="genai"

echo "GenAI-Stack Systemd Installation"
echo "================================="

# Create application user
if ! id "$APP_USER" &>/dev/null; then
    echo "Creating user $APP_USER..."
    sudo useradd -r -s /bin/bash $APP_USER
fi

# Create required directories
echo "Creating directories..."
sudo mkdir -p $INSTALL_DIR/uploaded_files
sudo mkdir -p $INSTALL_DIR/logs
sudo mkdir -p /var/lib/genai-stack/backups
sudo chown -R $APP_USER:$APP_GROUP $INSTALL_DIR
sudo chown -R $APP_USER:$APP_GROUP /var/lib/genai-stack

# Copy service files
echo "Installing systemd services..."

# Backend service
sudo tee /etc/systemd/system/genai-backend.service > /dev/null <<EOF
[Unit]
Description=GenAI Stack Backend API
After=network.target postgresql.service
Requires=postgresql.service

[Service]
Type=simple
User=$APP_USER
Group=$APP_GROUP
WorkingDirectory=$INSTALL_DIR/backend
Environment="PATH=$INSTALL_DIR/backend/myenv/bin"
Environment="PYTHONUNBUFFERED=1"
EnvironmentFile=$INSTALL_DIR/.env
ExecStart=$INSTALL_DIR/backend/myenv/bin/uvicorn app.main:app --host 0.0.0.0 --port 8000 --workers 4
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Frontend service (using nginx)
sudo tee /etc/systemd/system/genai-frontend.service > /dev/null <<EOF
[Unit]
Description=GenAI Stack Frontend
After=network.target

[Service]
Type=simple
ExecStart=/usr/sbin/nginx -g "daemon off;" -c $INSTALL_DIR/frontend-nginx.conf
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd daemon
echo "Reloading systemd daemon..."
sudo systemctl daemon-reload

# Enable services
echo "Enabling services..."
sudo systemctl enable genai-backend.service
sudo systemctl enable genai-frontend.service

echo ""
echo "Installation complete!"
echo ""
echo "To start services:"
echo "  sudo systemctl start genai-backend"
echo "  sudo systemctl start genai-frontend"
echo ""
echo "To check status:"
echo "  sudo systemctl status genai-backend"
echo "  sudo systemctl status genai-frontend"
echo ""
echo "To view logs:"
echo "  sudo journalctl -u genai-backend -f"
echo "  sudo journalctl -u genai-frontend -f"
