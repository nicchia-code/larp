---
column: done
technical: false
refs:
  - call/Ready/user.START
  - requirements/rules#call/Ready
drift: null
proposal: null
agent: false
created: 2026-10-13T16:03:32.252Z
finished: 2026-10-13T17:30:24.455Z
---
# Check microphone and PC audio on macOS when Avvia is pressed

Su macOS Avvia deve verificare, come su Linux, che esista un microfono predefinito e che l'audio del PC sia catturabile, con il permesso di registrazione concesso. Se una sorgente manca, Avvia non registra, resta in Pronto e l'app dice quale sorgente manca. Oggi il controllo esiste solo su Linux: su macOS Avvia genera un errore invece di verificare le sorgenti.
