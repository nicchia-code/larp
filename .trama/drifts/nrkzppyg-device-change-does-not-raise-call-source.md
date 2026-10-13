---
status: resolved
resolution: fix-code
refs:
  - call/Recording/call.SOURCE_LOST
  - requirements/tech#call/Recording
proposal: null
task: rytpodfx
origin: null
critical: false
option: 1
note: null
resolvedBy: hcj0ec0y
created: 2026-10-13T18:18:29.525Z
---
# Device change does not raise call.SOURCE_LOST with default-device capture

## What happens

Su Linux il microfono e l'audio del PC sono catturati con `parecord --device=@DEFAULT_SOURCE@` e `--device=@DEFAULT_MONITOR@` (`lib/call/audio_sources.dart`). Il codice emette `call.SOURCE_LOST` solo quando il processo di cattura termina (`CaptureProcess.exited`). Se durante la registrazione cambia il dispositivo predefinito (per esempio le cuffie scollegate), il processo, che segue il predefinito, può restare in vita: la call continua senza avviso e nessuna sorgente risulta persa. [INFERENCE: comportamento di PulseAudio/PipeWire con i nomi `@DEFAULT_*@`, da verificare a runtime.]

## What should happen

Il Model: `call.SOURCE_LOST` è emesso quando, durante la registrazione, il microfono o l'audio del PC smettono di arrivare, con "cuffie scollegate, dispositivo cambiato" come esempi. Il Requirement tech dice invece che SOURCE_LOST si produce con la fine inattesa del processo di cattura. Il codice segue il Requirement; con il Requirement così scritto il caso "dispositivo cambiato" del Model non è coperto.

## Fix options

### Legare la cattura al dispositivo di inizio call

Su Linux, all'Avvia si legge il nome del dispositivo predefinito (`pactl get-default-source` e `get-default-sink` con `.monitor`) e `parecord` lo riceve esplicito invece di `@DEFAULT_*@`. Se quel dispositivo sparisce, il processo termina e scatta SOURCE_LOST. Costo: se l'utente cambia dispositivo a metà call, la call resta sul dispositivo iniziale; il Model e il Requirement restano invariati. Da verificare a runtime.

### Rilevare il cambio del predefinito

La cattura resta sui predefiniti, e un cambio del dispositivo predefinito (`pactl subscribe` su Linux, notifica di cambio dispositivo su macOS) emette SOURCE_LOST. Costo: un ascoltatore di eventi di sistema per piattaforma; più codice nativo da mantenere.

### Cambiare il Model e il Requirement

Si toglie "dispositivo cambiato" dagli esempi di SOURCE_LOST e il Requirement tech resta com'è: un cambio di dispositivo non è una sorgente persa e la call continua sul nuovo predefinito. Costo: l'utente non viene avvisato del cambio di microfono a metà call.

## Where in the code

lib/call/audio_sources.dart (startCapture, _ParecordCapture.exited); lib/call/recorder.dart (CallRecorder.start, exited.then -> onSourceLost)
