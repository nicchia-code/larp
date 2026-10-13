---
column: done
technical: false
refs:
  - call/Ready
  - call/Nothing transcribed
  - call/Ready/user.START
  - call/Ready/user.CLOSE_WINDOW
  - call/Closed
  - requirements/rules#call/Ready
  - requirements/ui#call/Ready
drift: null
proposal: 8pfv4m4b
agent: false
created: 2026-10-13T15:50:02.977Z
finished: 2026-10-13T15:55:08.816Z
---
# Stato pronto: Avvia controlla le sorgenti e Chiudi chiude l'app

Nello stato pronto, prima di registrare Avvia verifica che il microfono e l'audio del PC siano disponibili. Se ne manca uno non si registra nulla, si resta pronti e l'app dice quale sorgente manca. Se entrambe sono disponibili la call passa a registrazione. Nessuna trascrizione è ancora avvenuta da quando l'app è aperta. Chiudere la finestra da pronto chiude l'app.
