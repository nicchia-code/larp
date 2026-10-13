---
column: done
technical: false
refs:
  - call/Waiting for models
  - call/Waiting for models/models.READY
  - call/Waiting for models/user.CLOSE_WINDOW
  - call/Closed
  - requirements/ui#call/Waiting for models
drift: null
proposal: 8pfv4m4b
agent: false
created: 2026-10-13T15:49:55.715Z
finished: 2026-10-13T15:53:30.652Z
---
# Attesa dei modelli: Avvia disabilitato fino a modelli pronti, chiusura che abbandona il download

Finché i modelli non sono pronti non si può registrare: il pulsante Avvia è visibile ma disabilitato. Quando i modelli diventano pronti (già presenti o appena scaricati) la call passa a pronta. Chiudere la finestra in questo stato chiude l'app e abbandona un eventuale download, che ripartirà da capo al prossimo avvio.
