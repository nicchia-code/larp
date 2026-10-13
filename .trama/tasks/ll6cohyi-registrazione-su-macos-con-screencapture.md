---
column: done
technical: false
refs:
  - call/Ready/user.START
  - call/Recording/call.SOURCE_LOST
  - requirements/tech#call/Recording
drift: null
proposal: null
agent: false
created: 2026-10-13T17:45:42.534Z
finished: 2026-10-13T18:05:28.449Z
---
# Registrazione su macOS con ScreenCaptureKit

Su macOS l'app registra le due sorgenti come su Linux: l'audio del PC e il microfono vengono catturati tramite il plugin nativo basato su ScreenCaptureKit, nello stesso file audio. Se la cattura di una sorgente finisce durante la registrazione, la call si ferma e si avvisa quale sorgente si è persa. Oggi su macOS l'avvio della cattura non è implementato e fallisce.
