---
status: resolved
resolution: fix-code
refs:
  - call/Ready/user.START
  - call/Recording/user.STOP
  - call/Recording/call.SOURCE_LOST
proposal: null
task: cv7xnd2i
origin: null
critical: false
option: 1
note: null
resolvedBy: e5yju4hz
created: 2026-10-13T17:54:14.821Z
---
# Second recording is not stopped and its file is not closed

## What happens

Dalla seconda call in poi, Ferma non chiude davvero la registrazione: il file audio resta aperto e le due catture continuano a girare in background. La trascrizione parte subito sul file ancora in scrittura, quindi la parte finale della call può mancare. Se una sorgente si perde durante la seconda registrazione, l'app non passa a Trascrizione e non dice quale sorgente si è persa. Ogni nuova registrazione lascia altre catture attive.

## What should happen

Ogni Avvia in Pronto apre una registrazione nuova e completa. Ferma chiude il file e le catture, poi trascrive tutto l'audio registrato. Se una sorgente si perde durante una registrazione, l'app passa a Trascrizione e dice quale sorgente si è persa, come per la prima call.

## Fix options

### Azzerare lo stato della registrazione a ogni avvio

Ogni Avvia riparte da una registrazione pulita: il file, le catture e la rilevazione della sorgente persa non ereditano nulla dalla call precedente. Ferma chiude sempre ciò che sta registrando e la perdita di una sorgente viene rilevata in ogni call. Costo: poche righe nel registratore, nessun cambio visibile all'utente.

### Usare un registratore nuovo per ogni call

Il controller crea un registratore nuovo a ogni call, invece di riusare quello della call precedente, così il file e le catture vecchi restano fuori dalla call nuova. Costo: il registratore viene costruito a ogni Avvia; Ferma deve comunque chiudere le catture della call corrente, quindi il controllo resta lo stesso.

## Where in the code

lib/call/recorder.dart (CallRecorder: _stopping e _stopped non vengono mai azzerati); lib/call/call_controller.dart (_recorder creato una sola volta nel costruttore)
