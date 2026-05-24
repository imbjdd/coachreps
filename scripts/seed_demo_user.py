#!/usr/bin/env python3
"""Seed a demo user with stats + 5 realistic sessions + unlocked badges for the Profile screenshot."""
import json
import subprocess
import urllib.request
from datetime import datetime, timedelta, timezone

PROJECT_ID = "coachreps-app"
USER_ID = "demo-screenshot"
BASE = f"https://firestore.googleapis.com/v1/projects/{PROJECT_ID}/databases/(default)/documents"
TOKEN = subprocess.check_output(["gcloud", "auth", "print-access-token"]).decode().strip()

def s(v): return {"stringValue": str(v)}
def i(v): return {"integerValue": str(int(v))}
def d(v): return {"doubleValue": float(v)}
def ts(v): return {"timestampValue": v}
def arr(values): return {"arrayValue": {"values": values}}

def patch(path, fields):
    url = f"{BASE}/{path}"
    body = json.dumps({"fields": fields}).encode()
    req = urllib.request.Request(url, data=body, method="PATCH",
                                 headers={"Authorization": f"Bearer {TOKEN}",
                                          "Content-Type": "application/json"})
    with urllib.request.urlopen(req) as r:
        return r.status

# User stats — level 5, 850 XP, 7-day streak, 12 drills, 4 badges
patch(f"users/{USER_ID}", {
    "totalXP": i(850),
    "level": i(5),
    "streak": i(7),
    "drillsCompleted": i(12),
    "lastDrillDate": s(datetime.now().strftime("%Y-%m-%d")),
    "lastFreezeDate": s(""),
    "unlockedBadges": arr([s("first_drill"), s("streak_3"), s("streak_7"), s("drills_10")]),
})
print("Stats seeded")

# 5 sessions — most recent at the top
sessions = [
    {
        "id": "sess-1",
        "drillId": "fp-marque-blanche",
        "drillTitle": "Demande de marque blanche",
        "drillType": "objection",
        "transcript": "Alors je comprends votre logique, mais l'avantage d'une intégration directe c'est que vous gardez le contrôle de la relation client. On peut tout à fait imaginer une formule co-brandée si c'est ce qui vous arrange.",
        "wpm": 152, "fillerCount": 1, "pauseCount": 2, "pitchVariation": 3.4, "durationSec": 18.2,
        "score": 78, "xp": 59,
        "analysis": "Bonne rebond sur le contrôle de la relation client. Tu rates l'occasion de qualifier la volumétrie d'usage avant de proposer une formule.",
        "improvements": ["Quantifie le volume d'usage avant de proposer un modèle", "Pose une question fermée pour valider l'intérêt co-branding"],
        "minutes_ago": 30,
    },
    {
        "id": "sess-2",
        "drillId": "fp-prix-pression",
        "drillTitle": "Pression sur le prix",
        "drillType": "objection",
        "transcript": "Je comprends. En fait notre tarif intègre le coaching personnalisé sur 8 semaines, c'est ce qui fait la vraie différence. On peut regarder ensemble ce qui vous semble crucial dans notre offre.",
        "wpm": 178, "fillerCount": 2, "pauseCount": 0, "pitchVariation": 2.1, "durationSec": 14.5,
        "score": 62, "xp": 51,
        "analysis": "Tu débites trop vite et tu enchaînes après le prix au lieu de marquer une pause. Le 'en fait' affaiblit ton positionnement.",
        "improvements": ["Pause d'1.5s avant et après l'annonce de la valeur", "Coupe les 'en fait' et 'du coup'"],
        "minutes_ago": 60 * 24,
    },
    {
        "id": "sess-3",
        "drillId": "fp-bricolage",
        "drillTitle": "On a déjà bricolé une solution",
        "drillType": "objection",
        "transcript": "C'est intéressant ce que vous dites. Beaucoup de nos clients sont passés par là. La vraie question c'est : combien de temps vos équipes passent chaque semaine à maintenir ce bricolage, et est-ce que c'est scalable ?",
        "wpm": 145, "fillerCount": 0, "pauseCount": 3, "pitchVariation": 4.2, "durationSec": 16.8,
        "score": 88, "xp": 64,
        "analysis": "Très bonne reformulation suivie d'une question puissante sur le coût caché. Tu utilises 3 pauses stratégiques qui donnent du poids.",
        "improvements": ["Ajoute un chiffre d'industrie pour appuyer ta question"],
        "minutes_ago": 60 * 48,
    },
    {
        "id": "sess-4",
        "drillId": "fp-concurrents",
        "drillTitle": "Question concurrents",
        "drillType": "objection",
        "transcript": "On en a plusieurs effectivement, les solutions custom ça vieillit assez mal. Les plus directs c'est CallTrack et RevInsight. Nous on est positionnés différemment parce qu'on couvre la vente terrain.",
        "wpm": 162, "fillerCount": 1, "pauseCount": 1, "pitchVariation": 3.0, "durationSec": 12.4,
        "score": 71, "xp": 55,
        "analysis": "Tu nommes les concurrents avec assurance, c'est bien. Mais tu n'enchaînes pas sur ce qui te différencie concrètement.",
        "improvements": ["Termine systématiquement par 1 phrase de différenciation"],
        "minutes_ago": 60 * 72,
    },
    {
        "id": "sess-5",
        "drillId": "fp-pas-de-methode",
        "drillTitle": "Quand on n'a pas de méthode formelle",
        "drillType": "objection",
        "transcript": "Très bonne question. Dans ce cas on co-construit la méthode avec vous dans les 2 premières semaines, à partir de ce qui marche déjà chez vos meilleurs commerciaux. C'est même un avantage parce que vous partez de zéro proprement.",
        "wpm": 156, "fillerCount": 0, "pauseCount": 2, "pitchVariation": 3.8, "durationSec": 19.1,
        "score": 82, "xp": 61,
        "analysis": "Tu transformes l'objection en avantage avec une mécanique claire. Bon rythme et bonnes pauses.",
        "improvements": ["Cite un client qui est parti dans cette config"],
        "minutes_ago": 60 * 96,
    },
]

iso = lambda dt: dt.strftime("%Y-%m-%dT%H:%M:%SZ")
now = datetime.now(timezone.utc)
for sess in sessions:
    completed = now - timedelta(minutes=sess["minutes_ago"])
    patch(f"users/{USER_ID}/sessions/{sess['id']}", {
        "drillId": s(sess["drillId"]),
        "drillTitle": s(sess["drillTitle"]),
        "drillType": s(sess["drillType"]),
        "transcript": s(sess["transcript"]),
        "wpm": i(sess["wpm"]),
        "fillerCount": i(sess["fillerCount"]),
        "pauseCount": i(sess["pauseCount"]),
        "pitchVariation": d(sess["pitchVariation"]),
        "durationSec": d(sess["durationSec"]),
        "score": i(sess["score"]),
        "xp": i(sess["xp"]),
        "analysis": s(sess["analysis"]),
        "improvements": arr([s(imp) for imp in sess["improvements"]]),
        "completedAt": ts(iso(completed)),
    })
    print(f"Session {sess['id']} seeded")

print("Done.")
