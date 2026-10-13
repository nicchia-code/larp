---
column: done
technical: false
refs:
  - models/Downloading
  - models/Downloading/models.DOWNLOAD_COMPLETED
  - models/Ready
  - requirements/ui#models/Downloading
  - requirements/tech#models
  - requirements/rules#models
  - requirements/data#models
drift: null
proposal: 8pfv4m4b
agent: false
created: 2026-10-13T15:50:09.025Z
finished: 2026-10-13T17:18:21.194Z
---
# Scaricare i modelli con avanzamento

Durante il download l'app mostra il testo di avanzamento, la barra e i MB scaricati sul totale, scarica EmbeddingGemma 2 da Hugging Face (variante int8) e il vocabolario audio dalla GitHub Release; quando tutti i file sono completi passa a Pronto.
