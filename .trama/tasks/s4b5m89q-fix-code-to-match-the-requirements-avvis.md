---
column: done
technical: true
refs:
  - requirements/ui#call/Transcribing
drift: 5vatmfcz
proposal: null
agent: false
created: 2026-10-13T17:47:07.912Z
finished: 2026-10-13T17:49:03.879Z
---
# Fix code to match the Requirements: Avviso della sorgente persa diverso da quello richiesto

## What happens

Quando una sorgente si perde, l'app mostra **Sorgente persa: Microfono** (o **Sorgente persa: Audio del PC**). Il testo è diverso e l'avviso resta visibile anche dopo la trascrizione, fino alla prossima registrazione.

## What should happen

Durante la trascrizione, se la registrazione si è fermata per una sorgente persa, l'app mostra **Microfono perso: registrazione fermata** oppure **Audio del PC perso: registrazione fermata**.

## Chosen option

**Testo richiesto, durante la trascrizione**

L'avviso usa esattamente il testo richiesto e compare solo mentre la trascrizione è in corso. Quando la trascrizione finisce con esito, l'avviso scompare e resta solo il risultato. Costo: un'informazione in meno sulla schermata dei risultati.

## Where in the code

lib/call/call_screen.dart (lostSource notice); lib/call/call_controller.dart (_sourceLost)
