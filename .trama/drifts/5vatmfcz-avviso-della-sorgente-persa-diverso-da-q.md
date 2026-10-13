---
status: resolved
resolution: fix-code
refs:
  - requirements/ui#call/Transcribing
proposal: null
task: s4b5m89q
origin: null
critical: false
option: 1
note: null
resolvedBy: wcli3rif
created: 2026-10-13T17:45:49.126Z
---
# Avviso della sorgente persa diverso da quello richiesto

## What happens

Quando una sorgente si perde, l'app mostra **Sorgente persa: Microfono** (o **Sorgente persa: Audio del PC**). Il testo è diverso e l'avviso resta visibile anche dopo la trascrizione, fino alla prossima registrazione.

## What should happen

Durante la trascrizione, se la registrazione si è fermata per una sorgente persa, l'app mostra **Microfono perso: registrazione fermata** oppure **Audio del PC perso: registrazione fermata**.

## Fix options

### Testo richiesto, durante la trascrizione

L'avviso usa esattamente il testo richiesto e compare solo mentre la trascrizione è in corso. Quando la trascrizione finisce con esito, l'avviso scompare e resta solo il risultato. Costo: un'informazione in meno sulla schermata dei risultati.

### Testo richiesto, fino alla prossima registrazione

L'avviso usa esattamente il testo richiesto, compare durante la trascrizione e resta sulla schermata dei risultati fino alla prossima registrazione, come oggi. Costo: nessun cambio di comportamento, solo il testo; l'avviso resta anche dopo la fine della trascrizione.

## Where in the code

lib/call/call_screen.dart (lostSource notice); lib/call/call_controller.dart (_sourceLost)
