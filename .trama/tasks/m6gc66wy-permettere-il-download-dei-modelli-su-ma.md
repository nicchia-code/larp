---
column: done
technical: true
refs:
  - requirements/tech#General
  - requirements/tech#models
drift: null
proposal: null
agent: false
created: 2026-10-13T18:11:11.140Z
finished: 2026-10-13T18:31:10.957Z
---
# Permettere il download dei modelli su macOS con la sandbox attiva

Su macOS l'app è sandboxed. Quando è attiva, l'app deve poter aprire connessioni di rete in uscita: il download dei modelli da Hugging Face e dalla GitHub Release deve funzionare sia nella build di debug sia in quella di release, e non deve aprire altre connessioni. Oggi il permesso di connessione in uscita manca in entrambe le configurazioni, quindi il download su macOS fallisce.
