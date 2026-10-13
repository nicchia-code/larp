---
column: done
technical: false
refs:
  - call/Ready
  - call/Transcript available
  - call/Transcript available/user.OPEN_TRANSCRIPT
  - call/Transcription failed
  - call/Transcription failed/user.RETRY_TRANSCRIPTION
  - requirements/ui#call/Transcript available
  - requirements/ui#call/Transcription failed
drift: null
proposal: null
agent: false
created: 2026-10-13T16:03:32.355Z
finished: 2026-10-13T17:37:55.121Z
---
# Show the last transcript outcome in the Ready state

Lo stato pronto deve distinguere Nessuna call trascritta, Ultima trascrizione pronta e Trascrizione fallita, e mostrare l'esito nella finestra: con la trascrizione pronta il nome del markdown e il pulsante Apri, che apre il markdown con l'applicazione predefinita del sistema; con la trascrizione fallita l'errore e il pulsante Riprova, che trascrive di nuovo lo stesso audio. Avvia resta disponibile in entrambi i casi. Oggi la vista dell'ultimo esito esiste già (card permanente nlm9w8rb, chiusa) ma non è collegata alla finestra né allo stato pronto, quindi nessuno dei due pulsanti è raggiungibile. La trascrizione stessa resta nella card permanente 7dx9qxpz.
