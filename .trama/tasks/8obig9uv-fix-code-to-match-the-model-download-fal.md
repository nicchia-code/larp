---
column: done
technical: false
refs:
  - models/Downloading/models.DOWNLOAD_FAILED
  - requirements/rules#models
drift: zoll4geo
proposal: null
agent: false
created: 2026-10-13T18:11:50.637Z
finished: 2026-10-13T18:13:37.047Z
---
# Fix code to match the Model: Download fallito cancella anche i modelli già presenti sul PC

## What happens

Quando il download dei modelli fallisce o viene interrotto, l'app cancella tutti i file dei modelli, anche quelli che erano già completi sul PC prima del tentativo. Succede, per esempio, quando manca solo il vocabolario audio e la rete cade nella fase di controllo delle dimensioni: al tentativo successivo l'intero set va riscaricato, e senza rete i modelli già presenti vanno persi.

## What should happen

Il Model dice che un download fallito scarta **solo quanto è stato scaricato fino a quel punto**: i file già completi sul PC non sono stati scaricati in quel tentativo e devono restare. Il Requirement dice che un download fallito cancella i **file parziali**, e che Riprova riparte da zero: non chiede di cancellare i file completi.

## Chosen option

**Scartare solo i file di questo tentativo**

Alla fine di un tentativo fallito si cancellano solo i file che il tentativo ha già scritto, più il parziale in corso. I file completi prima del tentativo restano sul PC finché un download riuscito non li sostituisce. Riprova continua a riscaricare tutto da zero, come chiede il Requirement. Costo: quasi nessuno; la cartella può contenere file nuovi e vecchi, ma tutti completi e della dimensione attesa.

## Where in the code

lib/models/model_download.dart (ModelDownloader.run e discard), lib/call/call_controller.dart (_download)
