---
status: resolved
resolution: fix-code
refs:
  - call/Recording/user.STOP
  - call/Transcribing
proposal: null
task: wolp5h5d
origin: null
critical: false
option: 1
note: null
resolvedBy: hcj0ec0y
created: 2026-10-13T18:18:18.201Z
---
# Recording stop fails while closing the audio file, leaving Transcribing stuck

## What happens

Se chiudere il file WAV fallisce (per esempio disco pieno), `CallRecorder.stop()` lancia un errore: `CallController.stop()` non arriva a `_transcribeRecording()`. Lo stato resta **Trascrizione in corso** con la barra ferma a 0%, Avvia resta disabilitato e la chiusura della finestra mostra "Attendi la fine della trascrizione." senza uscita. Un errore di scrittura durante la registrazione (`WavWriter._emit`) viene perso in silenzio e fa fallire anche la chiusura del file. Il Model non dice cosa succede in questo caso.

## What should happen

Il Model: `call/Recording/user.STOP` → Transcribing chiude il file audio e `call/Transcribing` finisce in Transcript available oppure Transcription failed (`call.TRANSCRIPTION_FAILED`: mostra l'errore, non scrive il markdown). Il Requirement data: il WAV si scrive durante la registrazione e si conserva dopo la trascrizione, riuscita o fallita. Nessuno dei due copre un errore di scrittura o di chiusura del file.

## Fix options

### Errore di chiusura del file in Trascrizione fallita

Se la chiusura o una scrittura del WAV fallisce, Ferma passa a Transcription failed con il messaggio d'errore, come per un errore di trascrizione. Il WAV resta sul disco, nessun markdown viene scritto e Riprova resta disponibile. Costo: un caso in più da gestire in `CallController.stop()`; il Model resta invariato.

### Trascrivere quanto è scritto

Se la chiusura fallisce, la trascrizione parte lo stesso sul WAV così com'è (il lettore accetta un file troncato). Costo: il markdown può mancare di parte della call senza che l'utente lo sappia.

### Aggiungere il caso al Model

Si aggiunge al Model un ramo per l'errore di scrittura del file audio, con l'esito voluto per l'utente. Costo: decisione di prodotto e modifica del Model, da fare fuori da questa analisi.

## Where in the code

lib/call/call_controller.dart (stop, _sourceLost); lib/call/recorder.dart (CallRecorder._stop, WavWriter._emit, WavWriter.close)
