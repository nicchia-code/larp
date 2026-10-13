---
column: done
technical: false
refs:
  - call/Recording/call.SOURCE_LOST
  - requirements/tech#call/Recording
drift: nrkzppyg
proposal: null
agent: false
created: 2026-10-13T18:19:43.233Z
finished: 2026-10-13T18:23:50.672Z
---
# Fix code to match the Model: Device change does not raise call.SOURCE_LOST with default-device capture

## What happens

Su Linux il microfono e l'audio del PC sono catturati con `parecord --device=@DEFAULT_SOURCE@` e `--device=@DEFAULT_MONITOR@` (`lib/call/audio_sources.dart`). Il codice emette `call.SOURCE_LOST` solo quando il processo di cattura termina (`CaptureProcess.exited`). Se durante la registrazione cambia il dispositivo predefinito (per esempio le cuffie scollegate), il processo, che segue il predefinito, può restare in vita: la call continua senza avviso e nessuna sorgente risulta persa. [INFERENCE: comportamento di PulseAudio/PipeWire con i nomi `@DEFAULT_*@`, da verificare a runtime.]

## What should happen

Il Model: `call.SOURCE_LOST` è emesso quando, durante la registrazione, il microfono o l'audio del PC smettono di arrivare, con "cuffie scollegate, dispositivo cambiato" come esempi. Il Requirement tech dice invece che SOURCE_LOST si produce con la fine inattesa del processo di cattura. Il codice segue il Requirement; con il Requirement così scritto il caso "dispositivo cambiato" del Model non è coperto.

## Chosen option

**Legare la cattura al dispositivo di inizio call**

Su Linux, all'Avvia si legge il nome del dispositivo predefinito (`pactl get-default-source` e `get-default-sink` con `.monitor`) e `parecord` lo riceve esplicito invece di `@DEFAULT_*@`. Se quel dispositivo sparisce, il processo termina e scatta SOURCE_LOST. Costo: se l'utente cambia dispositivo a metà call, la call resta sul dispositivo iniziale; il Model e il Requirement restano invariati. Da verificare a runtime.

## Where in the code

lib/call/audio_sources.dart (startCapture, _ParecordCapture.exited); lib/call/recorder.dart (CallRecorder.start, exited.then -> onSourceLost)
