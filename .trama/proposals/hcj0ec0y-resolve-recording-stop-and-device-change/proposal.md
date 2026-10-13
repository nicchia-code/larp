---
status: approved
kind: resolution
automatic: true
drifts:
  - drift: yf760mng
    decision: fix-code
    option: 1
  - drift: nrkzppyg
    decision: fix-code
    option: 1
base: {}
delete: []
created: 2026-10-13T18:19:35.014Z
---
# Resolve recording stop and device change Drifts

Risoluzione automatica dei Drift:
- D1 – Recording stop fails while closing the audio file, leaving Transcribing stuck: correzione del codice (opzione 1, un errore di chiusura o scrittura del file audio porta a Trascrizione fallita).
- D2 – Device change does not raise call.SOURCE_LOST with default-device capture: correzione del codice (opzione 1, la cattura resta legata al dispositivo attivo all'avvio della call).
