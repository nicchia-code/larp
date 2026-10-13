---
column: done
technical: false
refs:
  - call/Ready/user.START
drift: 8yu9pck8
proposal: null
agent: false
created: 2026-10-13T17:47:07.906Z
finished: 2026-10-13T17:48:55.662Z
---
# Fix code to match the Model: Avvio della registrazione fallito lascia l'app in registrazione

## What happens

Se la registrazione non può partire per un motivo diverso da una sorgente mancante (per esempio il file della call non si può creare, o la cattura su macOS non è disponibile), l'app passa comunque in **Registrazione in corso**. Il tempo non scorre e la registrazione non avviene. Premendo Ferma si tenta poi di trascrivere un file che può non esistere. Le catture già avviate restano attive in background.

## What should happen

Avvia registra solo se le due sorgenti sono disponibili. Se qualcosa non parte, l'app **resta in Pronto** e dice quale sorgente manca: non entra mai in registrazione senza registrare.

## Chosen option

**Restare in Pronto con il motivo**

Se l'avvio fallisce per qualunque motivo, l'app resta in Pronto e mostra il motivo: il nome della sorgente se si conosce, altrimenti il testo dell'errore. Le catture già avviate vengono fermate. Costo: poche righe nel flusso di avvio; nessuno stato nuovo.

## Where in the code

lib/call/call_controller.dart (start), lib/call/recorder.dart (start)
