---
column: todo
technical: false
refs:
  - models/Checking
  - models/Downloading
  - requirements/rules#models
  - requirements/tech#models
drift: null
proposal: null
agent: false
created: 2026-10-13T17:44:02.426Z
---
# Pubblicare il vocabolario audio e registrarne le dimensioni attese

Il vocabolario audio, generato una volta dallo sviluppatore su macOS con lo script del progetto, è pubblicato nella GitHub Release e l'indirizzo della Release è indicato all'app nella build. Per ciascuno dei due file del vocabolario l'app conosce la dimensione esatta, così il controllo all'avvio lo verifica come gli altri modelli. Quando tutti i file sono presenti con la dimensione attesa, l'avvio passa a Pronto; il download completo porta a Pronto invece di fallire. Finché il vocabolario non è pubblicato e le sue dimensioni non sono registrate, l'app non può arrivare a Pronto.
