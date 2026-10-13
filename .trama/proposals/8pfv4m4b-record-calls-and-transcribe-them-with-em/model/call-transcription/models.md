# Models

I modelli che servono alla trascrizione: EmbeddingGemma 2 e il vocabolario audio. Si scaricano una sola volta, al primo avvio.

## States

### Checking (initial)
All'avvio l'app verifica se i modelli sono già sul PC.
- `FOUND` → Ready
- `MISSING` → Downloading: inizia il download mostrando l'avanzamento.

### Downloading
- `DOWNLOAD_COMPLETED` → Ready
- `DOWNLOAD_FAILED` → Download failed: mostra l'errore e scarta quanto scaricato fino a quel punto.

### Download failed
- `user.RETRY_DOWNLOAD` → Downloading: il download riparte da capo.

### Ready (final)
I modelli sono sul PC e l'app può trascrivere.

## Events

### FOUND
Emesso quando all'avvio i modelli risultano già presenti e completi.

### MISSING
Emesso quando all'avvio manca almeno un modello o è incompleto.

### DOWNLOAD_COMPLETED
Emesso quando tutti i modelli sono stati scaricati.

### DOWNLOAD_FAILED
Emesso quando il download si interrompe o fallisce.

### READY
Emesso quando i modelli diventano pronti, sia perché già presenti sia perché appena scaricati.
