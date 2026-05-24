#!/bin/bash
# Re-seed /drills with French objections derived from the FormaPro Conseil call.
set -e
ACCESS_TOKEN=$(gcloud auth print-access-token)
PROJECT_ID="coachreps-app"
BASE="https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents"

# Wipe existing drills (any IDs from previous seeds)
for id in obj-price obj-timing obj-budget obj-decision obj-roi obj-implem obj-existing obj-trust redo-discovery redo-followup redo-demo redo-close pattern-fillers pattern-pace pattern-pitch; do
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

# Objections extraites du call FormaPro Conseil (Pierre Martin × Marc Dubois)
seed_drill "fp-personnalisation" "objection" "À quel point c'est personnalisable ?" "FormaPro · découverte produit" "À quel point c'est modifiable et personnalisable ?" 6
seed_drill "fp-script-methode" "objection" "Vous intégrez quelle méthode ?" "FormaPro · découverte produit" "Cette analyse, c'est par rapport à quoi ? On peut intégrer une méthode de vente, un script, des étapes ?" 9
seed_drill "fp-pas-de-methode" "objection" "Quand on n'a pas de méthode formelle" "FormaPro · objection produit" "Comment ça fonctionne ? Parce que toutes les boîtes n'ont pas une méthode de vente écrite avec les étapes. Comment vous travaillez quand ce n'est pas défini ?" 11
seed_drill "fp-concurrents" "objection" "Question concurrents" "FormaPro · objection concurrence" "Vous vous challengez par rapport à quel concurrent ? Qu'est-ce qu'il y a autour de vous ?" 8
seed_drill "fp-bricolage" "objection" "On a déjà bricolé une solution" "FormaPro · objection statu quo" "On bricole de notre côté avec Otter et ChatGPT, et franchement ça tourne plutôt bien pour nos besoins actuels." 9
seed_drill "fp-marque-blanche" "objection" "Demande de marque blanche" "FormaPro · objection modèle commercial" "Je pense beaucoup plus à une marque blanche pour qu'on puisse utiliser votre solution dans le cadre de notre métier." 10
seed_drill "fp-multi-clients" "objection" "Notre cas d'usage est différent" "FormaPro · objection use case" "Nous on a plein de clients différents. Avec votre exemple Habitat Plus, vous comprenez la boîte par cœur. Nous c'est autre chose." 11
seed_drill "fp-managers" "objection" "Et pour les managers ?" "FormaPro · objection scope" "On accompagne les boîtes, aussi bien les équipes commerciales que les managers. La problématique pour nous va être autre." 10
seed_drill "fp-prix-pression" "objection" "Pression sur le prix" "FormaPro · objection prix" "C'est clair, je vous ferai un outil pour notre business, donc il ne faut pas que vous nous creviez avec vos exigences financières." 11
seed_drill "fp-rgpd" "objection" "Est-ce que vous enregistrez ?" "FormaPro · objection conformité" "Excusez-moi, est-ce que vous enregistrez cette conversation ? Parce que ça, ça m'intéresse beaucoup, le côté RGPD et tout." 11
seed_drill "fp-transition-prix" "redo" "Transition vers le prix" "FormaPro · refais ce moment" "Bon, prochaine étape, il faut parler de sous. Comment vous fonctionnez ?" 7
seed_drill "fp-clarte-resume" "redo" "Reformuler en 2 phrases" "FormaPro · refais ce moment" "Si j'ai bien compris, on peut faire des enregistrements, les nourrir avec nos méthodes prédéfinies, et ensuite analyser les axes d'amélioration. C'est ça ?" 12
seed_drill "fp-pattern-rythme" "pattern" "Ralentis avant le prix" "Pattern récurrent" "Tu enchaînes systématiquement après l'annonce du prix. Refais ton annonce avec une pause de 1.5s minimum avant et après le chiffre." 9
seed_drill "fp-pattern-fillers" "pattern" "Refais sans \"en fait\"" "Pattern récurrent" "Tu as dit \"en fait\" 14 fois sur ce call. Refais ton pitch de 30 secondes sans le dire une seule fois." 8

echo "Done. Seeded 14 French drills from FormaPro."
