import os
import threading
import time

from flask import Flask, jsonify, request
from mfrc522 import SimpleMFRC522


app = Flask(__name__)
reader = SimpleMFRC522()
reader_lock = threading.Lock()

API_KEY = os.environ.get("RFID_API_KEY", "")
DEFAULT_SCAN_SECONDS = float(os.environ.get("RFID_SCAN_SECONDS", "8"))
MAX_SCAN_SECONDS = 30.0


def authorized() -> bool:
    return not API_KEY or request.headers.get("X-API-Key") == API_KEY


@app.before_request
def check_api_key():
    if not authorized():
        return jsonify({"error": "Unauthorized"}), 401


@app.get("/health")
def health():
    return jsonify({"status": "ok", "reader": "MFRC522"})


@app.post("/scan")
def scan():
    body = request.get_json(silent=True) or {}
    seconds = float(body.get("seconds", DEFAULT_SCAN_SECONDS))
    seconds = max(1.0, min(seconds, MAX_SCAN_SECONDS))

    if not reader_lock.acquire(blocking=False):
        return jsonify({"error": "A scan is already running"}), 409

    try:
        tags = []
        seen = set()
        deadline = time.monotonic() + seconds

        while time.monotonic() < deadline:
            tag_id = reader.read_id_no_block()
            if tag_id is not None:
                uid = str(tag_id)
                if uid not in seen:
                    seen.add(uid)
                    tags.append(uid)
            time.sleep(0.1)

        return jsonify(
            {
                "items": tags,
                "count": len(tags),
                "scan_seconds": seconds,
            }
        )
    finally:
        reader_lock.release()


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("RFID_PORT", "8000")))
