---
status: resolved
resolution: fix-code
refs:
  - models/Checking
proposal: null
task: 53p8g3ft
origin: zimckjox
critical: false
option: 1
note: null
resolvedBy: actfv1pl
created: 2026-10-13T15:52:29.607Z
---
# Dimensione attesa dei modelli non definita

## What happens

Per decidere se i modelli sono completi, il controllo all'avvio dovrebbe confrontare ogni file con una dimensione precisa. Il progetto però non dice quale sia: per EmbeddingGemma 2 c'è solo un'indicazione di circa 650 MB, per il vocabolario audio nessun valore, perché il file non è ancora generato né pubblicato. Senza un valore esatto per ciascun file non si può dire se l'app deve passare a Pronto o riscaricare.

## What should happen

Il Model dice che i modelli risultano presenti solo se tutti i file esistono con la dimensione attesa, e i Requirement della regola ripetono la stessa condizione. Nessuno dei due dice però da dove venga la dimensione attesa né quale sia per ogni file, quindi la regola non si può applicare senza una scelta che il Model non fa.

## Fix options

### Dimensioni esatte registrate nel progetto

Lo sviluppatore annota nel progetto la dimensione esatta di ogni file, presa dalla sorgente di Hugging Face e dalla GitHub Release. Al controllo i file vengono confrontati con questi valori, e l'app passa a Pronto solo se coincidono. Costo: il valore del vocabolario si conosce solo dopo la sua generazione e pubblicazione, e ogni nuova versione di un modello richiede di aggiornare i valori.

### Dimensioni registrate al termine del download

Quando un download riesce, l'app salva la dimensione di ogni file scaricato. All'avvio confronta i file con quanto salvato, e considera i modelli presenti solo se corrispondono. Costo: non serve conoscere le dimensioni in anticipo, ma un file alterato dopo il download non viene riconosciuto finché non si riscarica.

## Where in the code

Controllo dei modelli all'avvio
