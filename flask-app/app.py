import os

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


@app.route("/readyz")
def readyz():
    return jsonify(status="ready")
