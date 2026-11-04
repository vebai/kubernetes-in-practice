import os
import time

from flask import Flask, jsonify

app = Flask(__name__)


@app.route("/")
def index():
    return jsonify(
        app=os.environ.get("APP_NAME", "flask-app"),
        version=os.environ.get("APP_VERSION", "unknown"),
        message=os.environ.get("APP_MESSAGE", "Hello from Flask"),
    )


@app.route("/healthz")
def healthz():
    return jsonify(status="alive")



STARTED_AT = time.monotonic()
READY_AFTER = int(os.getenv("STARTUP_DELAY_SECONDS", "10"))

@app.route("/readyz")
def readyz():
    if time.monotonic() - STARTED_AT < READY_AFTER:
        return jsonify(status="not-ready"), 503
    return jsonify(status="ready"), 200
