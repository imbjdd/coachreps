#!/bin/bash
set -e
ACCESS_TOKEN=$(gcloud auth print-access-token)
PROJECT_ID="coachreps-app"
BASE="https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents"

# Delete existing French drills first
for id in obj-price-1 obj-timing-1 obj-budget-1 obj-decision-1 obj-roi-1 obj-implem-1 obj-existing-1 obj-trust-1 redo-discovery-1 redo-followup-1 redo-demo-1 redo-close-1 pattern-fillers-1 pattern-pace-1 pattern-pitch-1; do
  curl -s -X DELETE "${BASE}/drills/${id}" -H "Authorization: Bearer ${ACCESS_TOKEN}" > /dev/null
done
echo "Cleared old drills."

seed_drill() {
  local id="$1" type="$2" title="$3" context="$4" client_line="$5" duration="$6"
  curl -s -X PATCH \
    "${BASE}/drills/${id}" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{
      \"fields\": {
        \"type\": {\"stringValue\": \"${type}\"},
        \"title\": {\"stringValue\": \"${title}\"},
        \"context\": {\"stringValue\": \"${context}\"},
        \"clientLine\": {\"stringValue\": \"${client_line}\"},
        \"audioDuration\": {\"integerValue\": \"${duration}\"},
        \"createdAt\": {\"timestampValue\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}
      }
    }" > /dev/null
  echo "Seeded: $title"
}

seed_drill "obj-price" "objection" "Competitor is cheaper" "Closing call · price objection" "Your competitor is 30% cheaper. Why would I pay more with you?" 11
seed_drill "obj-timing" "objection" "Bad timing" "Discovery · timing objection" "We have other priorities this quarter. Let's revisit in Q3." 9
seed_drill "obj-budget" "objection" "No budget" "Discovery · budget objection" "We don't have budget allocated this year. We need to wait for next cycle." 10
seed_drill "obj-decision" "objection" "Not the decision maker" "Demo · authority objection" "I'm not the final decision maker. I need to run this by my CEO." 9
seed_drill "obj-roi" "objection" "Unclear ROI" "Negotiation · ROI objection" "I don't see a clear ROI over 6 months. Do you have actual numbers?" 11
seed_drill "obj-implem" "objection" "Heavy implementation" "Demo · implementation objection" "Your solution looks complex to roll out. We don't have the resources." 12
seed_drill "obj-existing" "objection" "We already have a tool" "Discovery · status quo objection" "We already use Salesforce. I don't see why we'd switch." 10
seed_drill "obj-trust" "objection" "Too young as a company" "Discovery · trust objection" "You're a young startup. We need long-term stability." 10
seed_drill "redo-discovery" "redo" "Discovery — qualify the need" "Redo this moment" "We're just looking around. Nothing specific for now." 8
seed_drill "redo-followup" "redo" "Follow-up after silence" "Redo this moment" "Sorry, I've been busy with other things. Let's talk later." 9
seed_drill "redo-demo" "redo" "Bounce on feature request" "Redo this moment" "Do you integrate with HubSpot? That's critical for us." 9
seed_drill "redo-close" "redo" "Closing — discount request" "Redo this moment" "We'll sign, but you need to drop 20%. Otherwise we'll go with the other one." 11
seed_drill "pattern-fillers" "pattern" "Redo without saying 'like'" "Pattern detected on your last 5 calls" "You said 'like' 14 times on that call. Redo your 30-second pitch without using it once." 7
seed_drill "pattern-pace" "pattern" "Slow down before the price" "Pattern detected" "You rush after the price. Redo the announcement with a 1.5s pause minimum before and after the number." 8
seed_drill "pattern-pitch" "pattern" "More vocal range" "Pattern detected" "Your voice is too flat on benefits. Redo with more intensity on key words." 8

echo "Done. Seeded 15 English drills."
