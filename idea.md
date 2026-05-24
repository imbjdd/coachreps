Coach Reps — L'app
Concept
Une app mobile de micro-entraînement vocal pour commerciaux. Format Duolingo : 3 minutes par jour, des drills courts à partir de moments réels extraits des meetings de l'équipe.
Comment ça marche

Le commercial ouvre l'app, voit son drill du jour (1 tap)
Il écoute un extrait audio court d'un vrai meeting (le sien ou celui d'un collègue) : "Le client dit : 'Votre concurrent est moins cher.'"
Il enregistre sa réponse vocale (30 secondes max)
L'IA score sa livraison sur 4 métriques : débit, mots fillers, variation tonale, pauses
Il écoute la réponse du top performer de l'équipe sur le même type de moment
Il peut refaire pour améliorer son score

Trois types de drills

Refais ce moment — réponds à la place du commercial sur un extrait passé
L'objection du jour — une vraie objection extraite d'un meeting récent
Tes patterns à toi — drill généré sur ta faiblesse spécifique (ex: "refais sans dire 'en fait'")

Métriques vocales mesurées

Débit en mots/minute
Mots fillers (euh, en fait, du coup, voilà)
Variation tonale (mélodie en demi-tons)
Pauses stratégiques vs hésitations
Langage faible (peut-être, je pense que)

Le twist clé
Pas de score en absolu. Toujours en comparaison du top performer de l'équipe sur le même type de moment. "Marc gère cette objection à 145 wpm avec 1.4s de pause avant le prix. Toi : 198 wpm, zéro pause."
Écrans principaux

Home : drill du jour + streak + 3 stats principales
Drill : écoute extrait → enregistre → score → comparaison top performer → refaire
Profil : tes patterns détectés, ton évolution sur 30 jours, tes faiblesses prioritaires

Stack
React Native (ou web mobile-first PWA pour aller plus vite). Backend Python : Whisper pour la transcription, parselmouth/librosa pour le pitch, LLM pour le scoring qualitatif. Tout async, pas de voice agent temps réel.
