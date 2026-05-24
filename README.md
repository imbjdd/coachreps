# Coach Reps

A Duolingo for sales reps. Native iOS app, 3 minutes a day.

---

## The problem

How do we turn Coach's data into something sales reps **actually use before
meetings**, with as little friction as possible?

A dashboard nobody opens, or a chatbot they have to interrogate, both miss
the point. The behavior needs to fit into the cracks of a sales rep's day —
in the train, between two clients, in the morning before a call.

## How I framed it

I started by looking at what works in this kind of behavior shaping. The
strongest reference is **Vocal Image**: 3-minute daily sessions, gamified,
AI feedback on voice delivery. The format is proven for solo, voluntary,
low-friction practice.

The next question was: what does Coach already have that no one else has?

The answer: **the sales plan**. Most coaching apps fight to define what
"good" looks like. Coach customers already wrote it down: the exact
methodology, the markers, what each phase of the meeting is supposed to
achieve. That's the rubric.

So the design decision was clear: instead of building a generic
voice-coaching app, build a daily training format **on top of the
customer's own sales plan**. The methodology is invisible to the rep —
it's how the AI grades — but it's what makes the feedback specific
instead of generic.

## What the app actually does

Every day the rep opens the app and gets a single drill (or a call
scenario derived from a real past meeting). They:

1. Read the situation (a real client objection or moment to handle)
2. Hit record. 30 seconds. Speak like it's live.
3. Optionally re-listen before sending — saves AI calls and lets them
   iterate
4. Get scored by Gemini against the customer's methodology

The score breakdown shows pace (wpm), filler words detected, strategic
pauses, pitch variation, plus AI analysis with concrete improvements
and 1-2 strengths. If a teammate has the same drill, the top performer's
metrics replace generic benchmarks.

Then: +XP, level progress, maybe a badge or streak update. Tomorrow,
new drill.

## Design choices

**3 minutes max, single tap to start.** The daily drill is on the Home
screen, not buried. Skip the listen step if you want to go faster. Re-record
without penalty. Anything that adds friction got cut.

**Gamification but tasteful.** XP, levels, badges, streak with a weekly
streak-freeze à la Duolingo. Level-up and badge-unlock overlays for the
small dopamine bump. No leaderboard-shouting, no push spam — one daily
reminder, time picked by the user.

**The methodology stays invisible.** A library tab shows *scenarios* the
rep can practice (objections + meeting-derived re-do moments + custom
drills). The 9-marker rubric of the Qualification methodology drives the
AI scoring in the background, but the rep never has to read a framework
doc. They just record and get feedback.

**Real call ingestion.** A rep (or admin) can drop in any audio file of
a past call. On-device transcription via Apple Speech, then Gemini
extracts 3-5 coachable moments and turns each into a new custom drill.
This is what lets the content stay fresh and relevant per company without
manual curation.

**Team comparison without auth.** Anyone with the same team code is on
the same leaderboard. Sessions get mirrored to `/teams/{CODE}/sessions`
on top of the user's private collection. Trades some security for zero
onboarding friction — fine for a prototype, would tighten with Firebase
Auth before scaling.

**French-first.** All UI, AI prompt, transcription locale, voice synth,
filler-detection regex set to French. The Gemini prompt explicitly says
*"réponds en français"* and uses a direct/challenging tone (style of
Patrick Bet-David, not LinkedIn).

## Stack and why

- **SwiftUI, iOS 16+** — native feel, AVFoundation and Speech framework
  give us on-device transcription with zero infrastructure.
- **Firestore via REST, no SDK** — the iOS SDK would have added 30+ MB
  and slow build times. The REST API does everything we need in ~200 lines.
  No Firebase Auth either — local UUID stored in `@AppStorage` since the
  free tier of Firebase Auth without billing is restrictive.
- **Gemini 2.5 Flash via REST** — structured JSON output via
  `responseSchema` makes parsing trivial. Coaching rubric is injected into
  the prompt at runtime when the drill comes from a methodology marker,
  so the AI grades against the customer's playbook, not a generic
  template.
- **Apple Speech (fr-FR) on-device** for ingestion of long call audios —
  no upload, no length limit, no cost.
- **Custom CoreGraphics-generated app icon** — kept the toolchain
  dependency-free.

## Trade-offs I made

- Open Firestore rules for prototyping — easy to attack, fine for a demo,
  would lock down with Firebase Auth before any real user. Documented in
  `firestore.rules`.
- Pitch detection via zero-crossing rate instead of a proper YIN
  autocorrelation — good enough to detect monotone delivery, would
  upgrade for production accuracy.
- Single category seeded (`Qualification` with 9 markers + one real
  meeting). Architecture handles N categories — just need to push more
  to `/categories` via `scripts/seed_library.py`.
- Gemini API key is baked into the app at build time via xcconfig (not
  in the repo). For a real product this should be proxied through a
  backend so users can't extract the key from the binary.

## Repo layout

```
CoachReps/                    iOS app
  CoachRepsApp + ContentView  3-tab shell: Home / Library / Profile
  HomeView                    Today's drill, XP bar, streak, stats
  LibraryView                 Unified scenario feed (meetings + drills
                              + custom), filter chips, contextual delete
  DrillView                   5 phases: listen → record → preview →
                              analyzing → results
  ProfileView                 Level, badges grid, pace trend,
                              patterns derived from sessions
  SessionDetailView           Tap a past session, see full analysis
  OnboardingView              First launch: splash → how it works → name
  SettingsView                Name, daily reminder time, team code,
                              reset, version
  AppState                    Central store, async bootstrap
  FirestoreClient             REST wrapper
  GeminiClient                Coaching analysis with rubric override
  SpeechTranscriber           SFSpeechRecognizer wrapper
  AudioEngine + AudioMetrics  Recording + pitch/pause/filler analysis
  CallIngestion + Import      Audio file → 3-5 custom drills via Gemini
  GameSystem                  XP / levels / badges / streak freeze
  NotificationManager         Local daily reminder
  Theme                       Warm off-white + terracotta accent

scripts/
  seed_drills_fr.sh           14 drills from a real FormaPro call
  seed_library.py             Categories + meeting recap to Firestore
  make_icon.swift             CoreGraphics → 1024×1024 app icon
```

## Run it

```sh
git clone git@github.com:imbjdd/coachreps.git
cd coachreps

# 1. Create a Gemini API key restricted to Generative Language
gcloud alpha services api-keys create \
  --display-name="CoachReps Gemini" \
  --project=YOUR_FIREBASE_PROJECT \
  --api-target=service=generativelanguage.googleapis.com

# 2. Drop the key in Secrets.xcconfig (gitignored)
cp CoachReps/Secrets.example.xcconfig CoachReps/Secrets.xcconfig
# edit Secrets.xcconfig

# 3. Open in Xcode and run
open CoachReps/CoachReps.xcodeproj
```
