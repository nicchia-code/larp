---
column: done
technical: false
refs:
  - call/Transcribing
  - call/Transcribing/call.TRANSCRIBED
  - call/Transcribing/call.TRANSCRIPTION_FAILED
  - call/Transcribing/user.CLOSE_WINDOW
  - call/Recording/call.SOURCE_LOST
  - call/Transcription failed/user.RETRY_TRANSCRIPTION
  - requirements/data#call/Transcribing
  - requirements/rules#call/Transcribing
  - requirements/tech#call/Transcribing
  - requirements/ui#call/Transcribing
drift: null
proposal: 8pfv4m4b
agent: false
created: 2026-10-13T15:50:19.973Z
finished: 2026-10-13T17:21:19.917Z
---
# Trascrizione dell'audio registrato in markdown con avanzamento e esito

Dopo lo stop, o dopo una sorgente persa, le tracce Io e Altri si trascrivono separatamente e il markdown viene scritto accanto all'audio, con titolo, durata e una riga per frase in ordine cronologico, oppure con la sola dicitura Nessun parlato rilevato se non c'è parlato. Durante la trascrizione Avvia è disabilitato e l'avanzamento è mostrato in percentuale. Se la trascrizione fallisce l'errore è mostrato e non viene scritto alcun markdown. Riprova trascrive di nuovo lo stesso audio. Tentare di chiudere la finestra durante la trascrizione la lascia aperta con un avviso che chiede di attendere la fine.
