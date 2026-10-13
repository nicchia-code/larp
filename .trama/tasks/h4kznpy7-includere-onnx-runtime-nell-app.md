---
column: done
technical: false
refs:
  - call/Transcribing
  - requirements/tech#call/Transcribing
drift: null
proposal: null
agent: false
created: 2026-10-13T17:45:42.663Z
finished: 2026-10-13T18:05:07.299Z
---
# Includere ONNX Runtime nell'app

L'app installata su Linux e macOS contiene la libreria ONNX Runtime con cui gira EmbeddingGemma 2, così la trascrizione funziona senza installazioni a parte. Oggi la libreria non viene inclusa nel pacchetto: la trascrizione di ogni call fallisce per mancanza del motore.
