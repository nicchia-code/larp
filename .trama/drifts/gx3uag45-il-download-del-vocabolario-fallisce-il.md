---
status: open
resolution: null
refs:
  - requirements/tech#models
proposal: null
task: null
origin: r9thowdt
critical: false
option: null
note: null
created: 2026-10-14T19:16:55.308Z
---
# Il download del vocabolario fallisce: il repo è privato

## What happens

La Release del vocabolario è pubblicata e le dimensioni sono registrate nell'app, ma GitHub risponde "non trovato" a una richiesta senza login: il repo è privato. Il download dei modelli quindi fallisce sempre e l'app non arriva mai a Pronto, nemmeno con i file già scaricati.

## What should happen

Il modello dice che il vocabolario si scarica da una Release del progetto e che, completato il download, l'app passa a Pronto. Con il repo privato l'app non ha un accesso con cui leggere la Release, quindi la Requirement sul download da GitHub Release non si può rispettare così com'è.

## Fix options

### Rendere pubblico il repo larp

La Release diventa scaricabile senza login e l'app non cambia. Costo: tutto il codice del repo diventa visibile a chiunque; prima va verificato che nella storia dei commit non ci siano segreti. Il vocabolario non contiene dati personali.

### Dare all'app un accesso di sola lettura alla Release

L'app manda con ogni download un token di accesso di sola lettura al repo privato. Costo: il token finisce nella build, quindi chi ha l'app può estrarlo e leggere il repo; va ruotato periodicamente e richiede un segreto disponibile al momento della build.

## Where in the code

lib/models/model_download.dart (download con richiesta anonima); MAC_VOCABULARY.md, sezione Attenzione: repo privato
