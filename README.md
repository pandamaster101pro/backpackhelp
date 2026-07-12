# Backpack Help

Flutter app with a Raspberry Pi 5 and RFID-RC522 backpack scanner.

1. Wire and install the Pi service by following
   [`raspberry_pi/README.md`](raspberry_pi/README.md).
2. For access from different Wi-Fi networks, install Tailscale on the phone
   and Pi, then sign both into the same Tailscale account.
3. In the app, open **Connection**, enter the Pi's Tailscale address such as
   `http://100.x.x.x:8000`, and tap **Save and test connection**.
4. Open **Bag Scan** and tap **Scan**.

The app asks the Pi to scan for eight seconds, receives the detected RFID tag
UIDs, and saves them in the signed-in user's Firestore `scanned_items` field.
