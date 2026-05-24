#!/usr/bin/env python3
"""Seed Firestore with categories (with markers) and meetings (with evaluations + transcript)."""
import json
import subprocess
import sys
import unicodedata
import urllib.request
import urllib.error
from pathlib import Path

PROJECT_ID = "coachreps-app"
BASE = f"https://firestore.googleapis.com/v1/projects/{PROJECT_ID}/databases/(default)/documents"

def access_token():
    return subprocess.check_output(["gcloud", "auth", "print-access-token"]).decode().strip()

TOKEN = access_token()

def patch(path, fields):
    url = f"{BASE}/{path}"
    body = json.dumps({"fields": fields}).encode()
    req = urllib.request.Request(url, data=body, method="PATCH",
                                 headers={"Authorization": f"Bearer {TOKEN}",
                                          "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req) as r:
            return r.status
    except urllib.error.HTTPError as e:
        print(f"  Error {e.code}: {e.read().decode()[:200]}")
        return e.code

def s(v): return {"stringValue": str(v)}
def i(v): return {"integerValue": str(int(v))}
def d(v): return {"doubleValue": float(v)}
def ts(v): return {"timestampValue": v}
def arr(values): return {"arrayValue": {"values": values}}
def m(d): return {"mapValue": {"fields": d}}

def slug(name):
    out = unicodedata.normalize("NFKD", name).encode("ascii", "ignore").decode("ascii")
    out = out.lower()
    out = out.replace(" ", "-").replace("'", "").replace(",", "")
    out = "".join(c for c in out if c.isalnum() or c == "-")
    return out

# --- Seed categories ---

CATEGORY_FILES = ["qualification.json"]

for fname in CATEGORY_FILES:
    path = Path(__file__).parent / "seed_data" / fname
    with open(path) as f:
        cat = json.load(f)
    cat_slug = slug(cat["category"])
    print(f"Seeding category: {cat['category']} ({cat_slug})")
    patch(f"categories/{cat_slug}", {
        "name": s(cat["category"]),
        "displayOrder": i(cat.get("displayOrder", 1)),
    })
    for marker in cat["markers"]:
        marker_slug = slug(marker["title"])
        path = f"categories/{cat_slug}/markers/{marker_slug}"
        print(f"  Marker: {marker['title']}")
        patch(path, {
            "title": s(marker["title"]),
            "displayOrder": i(marker["display_order"]),
            "description": s(marker["description"]),
            "shortDescription": s(marker["short_description"]),
        })

# --- Seed meetings ---

MEETING_FILES = [("meeting_formapro.json", "transcript_formapro.json")]

for meeting_file, transcript_file in MEETING_FILES:
    base = Path(__file__).parent / "seed_data"
    with open(base / meeting_file) as f:
        meta = json.load(f)
    with open(base / transcript_file) as f:
        transcript = json.load(f)

    meeting = meta["meeting"]
    meeting_id = meeting["id"]
    print(f"Seeding meeting: {meeting['title']} ({meeting_id})")

    transcript_values = [m({
        "speaker": s(line["speaker"]),
        "startMs": i(line["start_ms"]),
        "endMs": i(line["end_ms"]),
        "text": s(line["text"]),
    }) for line in transcript]

    evaluation_values = [m({
        "marker": s(ev["marker"]),
        "grade": (d(ev["grade"]) if ev.get("grade") is not None else {"nullValue": None}),
        "comment": s(ev.get("comment") or ""),
    }) for ev in meta["evaluations"]]

    patch(f"meetings/{meeting_id}", {
        "title": s(meeting["title"]),
        "category": s(meeting["category"]),
        "createdAt": ts(meeting["created_at"]),
        "feedback": s(meeting["feedback"]),
        "transcript": arr(transcript_values),
        "evaluations": arr(evaluation_values),
    })

print("Done.")
