# Call

La registrazione di una call, da Avvia fino al markdown scritto. Si registra una sola call alla volta.

## States

### Waiting for models (initial)
Non si può registrare finché i modelli non sono pronti.
- `models.READY` → Ready
- `user.CLOSE_WINDOW` → Closed: l'app si chiude; un download in corso viene abbandonato e ripartirà da capo al prossimo avvio.

### Ready
Si può avviare una nuova registrazione. Se all'Avvia manca il microfono o l'audio del PC, non si registra nulla, si resta qui e l'app dice quale sorgente manca.
- `user.START` → Recording: solo se microfono e audio del PC sono entrambi disponibili; inizia a registrare le due sorgenti in un nuovo file audio.
- `user.CLOSE_WINDOW` → Closed: l'app si chiude.

#### Nothing transcribed (initial)
Nessuna call trascritta da quando l'app è aperta.

#### Transcript available
L'ultima trascrizione è pronta.
- `user.OPEN_TRANSCRIPT` → Transcript available: apre l'ultimo markdown con l'applicazione predefinita del sistema.

#### Transcription failed
La trascrizione dell'ultima registrazione è fallita; il suo audio resta nella cartella. Avviare una nuova registrazione rinuncia a riprovare, ma l'audio resta.
- `user.RETRY_TRANSCRIPTION` → Transcribing: trascrive di nuovo lo stesso audio.

### Recording
Registra la tua voce dal microfono ("Io") e quella degli altri dall'audio del PC ("Altri") nello stesso file audio, mostrando la durata. Se l'app muore durante la registrazione, l'audio registrato fin lì resta nella cartella e non viene trascritto, né ora né ai successivi avvii.
- `user.STOP` → Transcribing: chiude il file audio.
- `SOURCE_LOST` → Transcribing: chiude il file audio e avvisa quale sorgente si è persa; si trascrive quanto registrato.
- `user.CLOSE_WINDOW` → Recording: la finestra resta aperta e un avviso chiede di fermare prima la registrazione.

### Transcribing
Trasforma l'audio registrato in testo, mostrando l'avanzamento. Non si può avviare un'altra registrazione.
- `TRANSCRIBED` → Transcript available: il markdown è scritto accanto all'audio; se non è stato riconosciuto alcun parlato, dice "Nessun parlato rilevato".
- `TRANSCRIPTION_FAILED` → Transcription failed: mostra l'errore; non viene scritto alcun markdown.
- `user.CLOSE_WINDOW` → Transcribing: la finestra resta aperta e un avviso chiede di attendere la fine della trascrizione.

### Closed (final)

## Events

### SOURCE_LOST
Emesso quando, durante la registrazione, il microfono o l'audio del PC smettono di arrivare (cuffie scollegate, dispositivo cambiato).

### TRANSCRIBED
Emesso quando il markdown della call è stato scritto.

### TRANSCRIPTION_FAILED
Emesso quando la trascrizione non riesce a completarsi.
