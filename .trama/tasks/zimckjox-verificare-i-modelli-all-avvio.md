---
column: done
technical: false
refs:
  - models/Checking
  - models/Checking/models.FOUND
  - models/Checking/models.MISSING
  - models/Ready
  - requirements/rules#models
  - requirements/data#models
drift: null
proposal: 8pfv4m4b
agent: false
created: 2026-10-13T15:50:08.915Z
finished: 2026-10-13T17:39:52.213Z
---
# Verificare i modelli all'avvio

All'avvio l'app controlla che i modelli siano sul PC: se tutti i file esistono con la dimensione attesa passa subito a Pronto; altrimenti, se manca almeno un modello o è incompleto, avvia il download.
