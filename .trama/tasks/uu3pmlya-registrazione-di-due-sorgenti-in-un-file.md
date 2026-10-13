---
column: done
technical: false
refs:
  - call/Recording
  - call/Recording/user.STOP
  - call/Recording/call.SOURCE_LOST
  - call/Recording/user.CLOSE_WINDOW
  - call/Ready/user.START
  - requirements/data#call/Recording
  - requirements/tech#call/Recording
  - requirements/ui#call/Recording
drift: null
proposal: 8pfv4m4b
agent: false
created: 2026-10-13T15:50:14.848Z
finished: 2026-10-13T16:59:40.729Z
---
# Registrazione di due sorgenti in un file audio, con fermata e gestione della sorgente persa

Avvia, se microfono e audio del PC sono entrambi disponibili, registra la voce dell'utente (Io) e l'audio del PC (Altri) nello stesso file audio stereo scritto su disco durante la registrazione, mostrando la durata. Ferma chiude il file e passa alla trascrizione. Se una sorgente smette di arrivare, la registrazione si ferma da sola, l'app avvisa quale sorgente si è persa e trascrive quanto registrato. Tentare di chiudere la finestra durante la registrazione la lascia aperta con un avviso che chiede di fermare prima. L'audio già registrato resta nella cartella.
