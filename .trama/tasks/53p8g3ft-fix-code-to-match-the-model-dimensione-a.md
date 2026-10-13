---
column: done
technical: false
refs:
  - models/Checking
drift: mjcds8r0
proposal: 8pfv4m4b
agent: false
created: 2026-10-13T15:58:36.427Z
finished: 2026-10-13T17:36:45.464Z
---
# Fix code to match the Model: Dimensione attesa dei modelli non definita

## What happens

Per decidere se i modelli sono completi, il controllo all'avvio dovrebbe confrontare ogni file con una dimensione precisa. Il progetto però non dice quale sia: per EmbeddingGemma 2 c'è solo un'indicazione di circa 650 MB, per il vocabolario audio nessun valore, perché il file non è ancora generato né pubblicato. Senza un valore esatto per ciascun file non si può dire se l'app deve passare a Pronto o riscaricare.

## What should happen

Il Model dice che i modelli risultano presenti solo se tutti i file esistono con la dimensione attesa, e i Requirement della regola ripetono la stessa condizione. Nessuno dei due dice però da dove venga la dimensione attesa né quale sia per ogni file, quindi la regola non si può applicare senza una scelta che il Model non fa.

## Chosen option

**Dimensioni esatte registrate nel progetto**

Lo sviluppatore annota nel progetto la dimensione esatta di ogni file, presa dalla sorgente di Hugging Face e dalla GitHub Release. Al controllo i file vengono confrontati con questi valori, e l'app passa a Pronto solo se coincidono. Costo: il valore del vocabolario si conosce solo dopo la sua generazione e pubblicazione, e ogni nuova versione di un modello richiede di aggiornare i valori.

## Where in the code

Controllo dei modelli all'avvio
