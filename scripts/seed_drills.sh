#!/bin/bash
set -e
ACCESS_TOKEN=$(gcloud auth print-access-token)
PROJECT_ID="coachreps-app"
BASE="https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents"

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

seed_drill "obj-price-1" "objection" "Le prix concurrent" "Closing call · objection prix" "Votre concurrent est moins cher de 30%. Pourquoi je paierais plus chez vous ?" 12
seed_drill "obj-timing-1" "objection" "Pas le bon timing" "Discovery · objection timing" "On a d'autres priorités ce trimestre. On reverra ça au Q3." 10
seed_drill "obj-budget-1" "objection" "Pas de budget" "Discovery · objection budget" "On n'a pas de budget alloué cette année, on doit attendre la prochaine clôture." 11
seed_drill "obj-decision-1" "objection" "Pas le décideur" "Demo · objection autorité" "Je ne suis pas le décisionnaire final, il faut que j'en parle à mon CEO." 9
seed_drill "obj-roi-1" "objection" "ROI peu clair" "Negotiation · objection ROI" "Je ne vois pas concrètement le ROI sur 6 mois, vous avez des chiffres ?" 13
seed_drill "obj-implem-1" "objection" "Implémentation lourde" "Demo · objection implem" "Votre solution a l'air complexe à mettre en place, on n'a pas les ressources." 14
seed_drill "obj-existing-1" "objection" "On a déjà un outil" "Discovery · objection statu quo" "On utilise déjà Salesforce, je vois pas pourquoi on changerait." 11
seed_drill "obj-trust-1" "objection" "Trop jeune comme boîte" "Discovery · objection confiance" "Vous êtes une jeune startup, on a besoin de stabilité long terme." 12
seed_drill "redo-discovery-1" "redo" "Discovery — qualifier le besoin" "Refais ce moment" "On regarde un peu, on n'a rien de précis pour l'instant." 8
seed_drill "redo-followup-1" "redo" "Relance après silence radio" "Refais ce moment" "Désolé, j'ai été pris par d'autres sujets, on en reparle plus tard." 9
seed_drill "redo-demo-1" "redo" "Rebondir sur demande de feature" "Refais ce moment" "Est-ce que vous avez l'intégration avec HubSpot ? C'est critique pour nous." 10
seed_drill "redo-close-1" "redo" "Closing — demande de discount" "Refais ce moment" "On signe, mais il faut que vous baissiez de 20%, sinon on prend l'autre." 12
seed_drill "pattern-fillers-1" "pattern" "Refais sans dire \"en fait\"" "Pattern détecté sur tes 5 derniers calls" "Tu as dit \"en fait\" 14 fois sur ce call. Refais ton pitch de 30 secondes sans le dire une seule fois." 6
seed_drill "pattern-pace-1" "pattern" "Ralentis avant le prix" "Pattern détecté" "Tu enchaînes après le prix. Refais l'annonce avec une pause de 1.5s minimum avant et après le chiffre." 7
seed_drill "pattern-pitch-1" "pattern" "Plus de variation tonale" "Pattern détecté" "Ta voix est trop monotone sur les bénéfices. Refais avec plus d'intensité sur les mots clés." 8

echo "Done. Seeded 15 drills."
