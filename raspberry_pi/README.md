# Raspberry Pi 5 + RFID-RC522

The Flutter app talks to this service through Tailscale, so the phone and Pi
can be on different Wi-Fi or mobile networks.

## Wiring

Power off the Pi before wiring. The RC522 is a **3.3V-only** device.

| RC522 pin | Raspberry Pi 5 pin |
| --- | --- |
| SDA / SS | GPIO 8, physical pin 24 |
| SCK | GPIO 11, physical pin 23 |
| MOSI | GPIO 10, physical pin 19 |
| MISO | GPIO 9, physical pin 21 |
| IRQ | Not connected |
| GND | Ground, physical pin 6 |
| RST | GPIO 25, physical pin 22 |
| 3.3V | 3.3V, physical pin 1 |

## Install

The easiest installation method configures SPI, the RFID API, automatic
startup, Tailscale remote access, and an API key:

```bash
chmod +x install_everything.sh
./install_everything.sh
```

The script may print a Tailscale sign-in URL. Open it and approve the Pi. When
finished, the script prints the address and API key to enter in the Flutter
app.

Verify from a device signed into the same Tailscale account:

```bash
curl -H "X-API-Key: YOUR_KEY" http://100.x.x.x:8000/health
curl -X POST http://100.x.x.x:8000/scan \
  -H "X-API-Key: YOUR_KEY" \
  -H "Content-Type: application/json" \
  -d '{"seconds":8}'
```

The scan response contains RC522 tag UIDs:

```json
{"count":2,"items":["123456789","987654321"],"scan_seconds":8.0}
```

## Connect from different Wi-Fi networks

Raspberry Pi Connect only provides remote desktop and shell access. Tailscale
provides the private network connection used by the Flutter app.

On the Pi, from this directory:

```bash
chmod +x setup_remote_access.sh
./setup_remote_access.sh
```

The command prints an address similar to:

```text
http://100.101.102.103:8000
```

Install the Tailscale app on the phone, sign in using the same Tailscale
account, and turn Tailscale on. Enter the printed address in the Flutter
**Connection** screen.

The script also creates an API key in `/etc/backpack-rfid.env`. Enter the
printed API key in the Flutter connection screen. The systemd service reads
the key automatically.

To replace the API key later, run:

```bash
RFID_API_KEY="$(openssl rand -hex 24)" ./setup_remote_access.sh
sudo systemctl daemon-reload
sudo systemctl restart rfid-api
```
