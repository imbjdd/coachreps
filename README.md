# Coach Reps

Duolingo-style voice training for sales reps. 3 minutes a day.

Native iOS SwiftUI app. Records your response to a real client objection,
transcribes it on-device (Apple Speech, fr-FR), computes voice metrics
(pace, fillers, pauses, pitch variation), and ships them to Gemini for
a tough coaching analysis. Gamified: XP, levels, badges, streak with
weekly streak-freeze. Team leaderboard via shared code. Import a real
call audio → AI extracts 3-5 coachable client moments as custom drills.

## Stack

- iOS 16+, SwiftUI, AVFoundation, Speech framework
- Firebase Firestore (REST, no SDK)
- Gemini 2.5 Flash (via REST, key injected at build time)

## Setup

```sh
# Clone
git clone git@github.com:imbjdd/coachreps.git
cd coachreps

# 1. Get a Gemini API key
gcloud alpha services api-keys create \
  --display-name="CoachReps Gemini" \
  --project=YOUR_FIREBASE_PROJECT \
  --api-target=service=generativelanguage.googleapis.com

# 2. Drop it in Secrets.xcconfig
cp CoachReps/Secrets.example.xcconfig CoachReps/Secrets.xcconfig
# edit Secrets.xcconfig with your key

# 3. Open in Xcode and run
open CoachReps/CoachReps.xcodeproj
```

## Firestore

Seed scripts in `scripts/`:
- `seed_drills_fr.sh` — 14 drills derived from a real FormaPro call
- `seed_library.py` — pushes a Qualification methodology category (9 markers)
  + the FormaPro meeting (transcript + per-marker evaluations)

Rules are open by default for local dev — tighten before any public release.

## Architecture

```
CoachReps/
├── CoachRepsApp.swift, ContentView.swift  — app entry + tab shell
├── HomeView, LibraryView, ProfileView     — 3 main tabs
├── DrillView                              — 5-phase recording flow
├── OnboardingView, SettingsView           — first-launch + settings sheet
├── AppState                               — central store, Firestore bootstrap
├── FirestoreClient                        — REST wrapper (drills, sessions,
│                                            meetings, categories, teams)
├── GeminiClient                           — coaching analysis with rubric override
├── SpeechTranscriber, AudioEngine,        — on-device recording + transcription
│   AudioMetrics                             + pitch + filler detection
├── CallIngestion                          — audio file → extracted drills
├── GameSystem                             — XP, levels, badges, streak freeze
├── NotificationManager                    — local daily reminders
└── Theme                                  — warm off-white + terracotta palette
```
