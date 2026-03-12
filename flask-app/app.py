import os
from flask import Flask, render_template, jsonify

app = Flask(__name__)


@app.route("/")
def index():
    context = {
        "title": os.environ.get("PAGE_TITLE", "Welcome to Flask-Nginx App"),
        "message": os.environ.get("WELCOME_MESSAGE", "Hello from Kubernetes!"),
        "version": os.environ.get("APP_VERSION", "1.0"),
        "bg_color": os.environ.get("BG_COLOR", "#eef2ff"),
        "accent_color": os.environ.get("ACCENT_COLOR", "#4f46e5"),
    }
    return render_template("index.html", **context)


@app.route("/health")
def health():
    return jsonify(
        {
            "status": "healthy",
            "version": os.environ.get("APP_VERSION", "1.0"),
        }
    )


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=False)
