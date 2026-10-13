---
column: done
technical: false
refs:
  - call/Recording/user.STOP
  - call/Transcribing
drift: yf760mng
proposal: null
agent: false
created: 2026-10-13T18:19:43.227Z
finished: 2026-10-13T18:22:32.627Z
---
# Fix code to match the Model: Recording stop fails while closing the audio file, leaving Transcribing stuck

## What happens

Se chiudere il file WAV fallisce (per esempio disco pieno), `CallRecorder.stop()` lancia un errore: `CallController.stop()` non arriva a `_transcribeRecording()`. Lo stato resta **Trascrizione in corso** con la barra ferma a 0%, Avvia resta disabilitato e la chiusura della finestra mostra "Attendi la fine della trascrizione." senza uscita. Un errore di scrittura durante la registrazione (`WavWriter._emit`) viene perso in silenzio e fa fallire anche la chiusura del file. Il Model non dice cosa succede in questo caso.

## What should happen

Il Model: `call/Recording/user.STOP` → Transcribing chiude il file audio e `call/Transcribing` finisce in Transcript available oppure Transcription failed (`call.TRANSCRIPTION_FAILED`: mostra l'errore, non scrive il markdown). Il Requirement data: il WAV si scrive durante la registrazione e si conserva dopo la trascrizione, riuscita o fallita. Nessuno dei due copre un errore di scrittura o di chiusura del file.

## Chosen option

**Errore di chiusura del file in Trascrizione fallita**

Se la chiusura o una scrittura del WAV fallisce, Ferma passa a Transcription failed con il messaggio d'errore, come per un errore di trascrizione. Il WAV resta sul disco, nessun markdown viene scritto e Riprova resta disponibile. Costo: un caso in più da gestire in `CallController.stop()`; il Model resta invariato.

## Where in the code

lib/call/call_controller.dart (stop, _sourceLost); lib/call/recorder.dart (CallRecorder._stop, WavWriter._emit, WavWriter.close)
