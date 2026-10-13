---
column: done
technical: false
refs:
  - models/Downloading/models.DOWNLOAD_FAILED
  - requirements/rules#models
drift: null
proposal: null
agent: false
created: 2026-10-13T18:16:21.772Z
finished: 2026-10-13T18:32:11.030Z
---
# Keep complete model files when a retried download fails

Un download fallito, anche quello di Riprova, deve lasciare intatti i modelli già completi sul PC. Oggi, se il download riscrive un file già completo (Riprova riscarica tutto da zero) e poi la rete cade, quel file completo viene cancellato insieme ai parziali: per esempio la rete cade durante il vocabolario audio, dopo che EmbeddingGemma 2 è stato riscaricato. Deve essere vero che: un file del tentativo entra nella cartella dei modelli solo quando tutto il set è scaricato e completo; un tentativo fallito elimina solo quanto ha scaricato fino a quel punto e lascia i modelli che c'erano prima; Riprova continua a scaricare tutto da zero.
