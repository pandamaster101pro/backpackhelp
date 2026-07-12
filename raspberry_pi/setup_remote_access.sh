#!/usr/bin/env bash
set -euo pipefail

if [[ $EUID -eq 0 ]]; then
  echo "Run this script as your normal Raspberry Pi user, not with sudo."
  exit 1
fi

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
api_key="${RFID_API_KEY:-$(openssl rand -hex 24)}"

printf 'RFID_API_KEY=%s\n' "${api_key}" | sudo tee /etc/backpack-rfid.env >/dev/null
sudo chmod 600 /etc/backpack-rfid.env

if systemctl cat rfid-api.service >/dev/null 2>&1; then
  sudo systemctl daemon-reload
  sudo systemctl restart rfid-api
fi

echo
echo "Remote access is ready."
echo "Install Tailscale on your phone and sign in to the same account."
echo "Then enter this address in the Flutter app:"
echo
echo "http://${tailscale_ip}:8000"
echo
echo "API key:"
echo "${api_key}"
