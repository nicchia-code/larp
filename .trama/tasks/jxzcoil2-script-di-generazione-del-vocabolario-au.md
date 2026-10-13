---
column: done
technical: true
refs:
  - requirements/tech#models
  - requirements/data#models
drift: null
proposal: null
agent: false
created: 2026-10-13T15:50:08.973Z
finished: 2026-10-13T16:59:19.374Z
---
# Script di generazione del vocabolario audio

Il progetto contiene lo script, eseguito dallo sviluppatore su macOS, che per ogni parola italiana e inglese sintetizza l'audio con le voci maschile e femminile di say, lo porta a mono 16 kHz, calcola l'embedding con EmbeddingGemma 2 (int8) e salva i vettori a 768 dimensioni nel vocabolario pubblicato in GitHub Release.
