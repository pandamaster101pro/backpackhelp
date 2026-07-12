#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
install_dir="${HOME}/backpack-rfid"
service_file="/etc/systemd/system/rfid-api.service"
env_file="/etc/backpack-rfid.env"

if [[ $EUID -eq 0 ]]; then
  echo "Run this script as your normal Raspberry Pi user, not with sudo."
  exit 1
fi

echo "Enabling SPI and installing Raspberry Pi dependencies..."
sudo raspi-config nonint do_spi 0
sudo apt-get update
sudo apt-get install -y \
  curl \
  openssl \
  python3-rpi-lgpio \
  python3-spidev \
  python3-venv

echo "Installing the RFID API..."
mkdir -p "${install_dir}"
cp "${script_dir}/rfid_api.py" "${script_dir}/requirements.txt" "${install_dir}/"
python3 -m venv --system-site-packages "${install_dir}/.venv"
"${install_dir}/.venv/bin/pip" install --upgrade pip
"${install_dir}/.venv/bin/pip" install --no-deps mfrc522==0.0.7
"${install_dir}/.venv/bin/pip" install Flask==3.1.1

api_key="${RFID_API_KEY:-$(openssl rand -hex 24)}"
printf 'RFID_API_KEY=%s\n' "${api_key}" | sudo tee "${env_file}" >/dev/null
sudo chmod 600 "${env_file}"

echo "Installing the RFID API system service..."
sudo tee "${service_file}" >/dev/null <<EOF
[Unit]
Description=Backpack RFID API
After=network-online.target tailscaled.service
Wants=network-online.target tailscaled.service

[Service]
Type=simple
User=${USER}
WorkingDirectory=${install_dir}
Environment=RFID_PORT=8000
EnvironmentFile=-${env_file}
ExecStart=${install_dir}/.venv/bin/python ${install_dir}/rfid_api.py
Restart=on-failure
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now rfid-api

echo "Installing and connecting Tailscale..."
if ! command -v tailscale >/dev/null 2>&1; then
  curl -fsSL https://tailscale.com/install.sh | sh
fi
sudo systemctl enable --now tailscaled

if [[ -n "${TAILSCALE_AUTH_KEY:-}" ]]; then
  sudo tailscale up --auth-key="${TAILSCALE_AUTH_KEY}"
else
  sudo tailscale up
fi

tailscale_ip="$(tailscale ip -4 | head -n 1)"

echo
echo "=============================================="
echo "Backpack RFID setup complete"
echo "Address: http://${tailscale_ip}:8000"
echo "API key: ${api_key}"
echo "=============================================="
echo
echo "Install Tailscale on the phone, sign into the same account, and enter"
echo "the address and API key above in the Flutter app's Connection screen."
