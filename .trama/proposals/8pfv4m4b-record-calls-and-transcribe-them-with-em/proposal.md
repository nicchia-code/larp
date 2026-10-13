---
status: approved
base:
  system.md: c91e06ca4d0dc21f90d06ac9709f99ff34cb71f44ec476959f240496ed896ceb
  actors/user.md: new
  call-transcription/feature.md: new
  call-transcription/models.md: new
  call-transcription/call.md: new
  requirements/tech/main.md: new
  requirements/data/main.md: new
  requirements/rules/main.md: new
  requirements/ui/main.md: new
  requirements/quality/main.md: new
delete: []
request: 2026-10-13T17-28-36
created: 2026-10-13T15:46:07.389Z
scanScope:
  - ref: call-transcription
    reason: changed
  - ref: user
    reason: changed
  - ref: user.START
    reason: changed
  - ref: user.STOP
    reason: changed
  - ref: user.RETRY_DOWNLOAD
    reason: changed
  - ref: user.RETRY_TRANSCRIPTION
    reason: changed
  - ref: user.OPEN_TRANSCRIPT
    reason: changed
  - ref: user.CLOSE_WINDOW
    reason: changed
  - ref: call
    reason: changed
  - ref: models
    reason: changed
  - ref: requirements/data#General
    reason: changed
  - ref: requirements/data#call/Recording
    reason: changed
  - ref: requirements/data#call/Transcribing
    reason: changed
  - ref: requirements/data#models
    reason: changed
  - ref: requirements/quality#General
    reason: changed
  - ref: requirements/rules#call/Ready
    reason: changed
  - ref: requirements/rules#call/Transcribing
    reason: changed
  - ref: requirements/rules#models
    reason: changed
  - ref: requirements/tech#General
    reason: changed
  - ref: requirements/tech#call/Recording
    reason: changed
  - ref: requirements/tech#call/Transcribing
    reason: changed
  - ref: requirements/tech#models
    reason: changed
  - ref: requirements/ui#General
    reason: changed
  - ref: requirements/ui#models/Downloading
    reason: changed
  - ref: requirements/ui#models/Download failed
    reason: changed
  - ref: requirements/ui#call/Waiting for models
    reason: changed
  - ref: requirements/ui#call/Ready
    reason: changed
  - ref: requirements/ui#call/Transcript available
    reason: changed
  - ref: requirements/ui#call/Transcription failed
    reason: changed
  - ref: requirements/ui#call/Recording
    reason: changed
  - ref: requirements/ui#call/Transcribing
    reason: changed
---
# Record calls and transcribe them with EmbeddingGemma 2

Prima versione di CallToRecord: un'app desktop Flutter minimale che registra microfono e audio del PC durante le call e, a fine call, scrive in un file markdown la trascrizione italiana ottenuta con EmbeddingGemma 2, confrontando l'audio con un vocabolario audio generato via TTS (idea ispirata a https://eg2.haku.sh/, il cui reader è solo inglese e non pubblico).

Decisioni prese nell'intervista:
- Contenuto del markdown: trascrizione completa.
- Lingua delle call: italiano (vocabolario italiano + inglese).
- Piattaforme: Linux e macOS.
- Forma: una finestra minima, testi solo in italiano.
- Registrazione: avvio e arresto manuali; elaborazione dopo lo stop.
- Voci: distinte in "Io" (microfono) e "Altri" (audio del PC); si assume l'uso delle cuffie, nessuna gestione dell'eco.
- Audio: conservato come un WAV stereo (Io a sinistra, Altri a destra) accanto al markdown.
- Elaborazione fallita: errore e pulsante Riprova; Avvia resta disponibile e una nuova registrazione fa sparire Riprova.
- Sorgente mancante all'avvio: la registrazione non parte e l'app dice quale sorgente manca.
- Sorgente persa durante la registrazione: la registrazione si ferma da sola, l'app avvisa e trascrive quanto registrato.
- Una sola registrazione alla volta: Avvia disabilitato durante l'elaborazione.
- File salvati in una cartella fissa, un file per call con data e ora nel nome.
- Motore: EmbeddingGemma 2 (ONNX, int8) eseguito con ONNX Runtime; nessun reader né addestramento: ogni spezzone della call si confronta con un vocabolario audio.
- Vocabolario audio: ~50.000 parole italiane + ~20.000 inglesi, pronunciate dalle voci di macOS (`say`), una maschile e una femminile per lingua, vettori pieni a 768 dimensioni; calcolato una volta dallo sviluppatore con uno script del progetto e pubblicato in una GitHub Release.
- Modelli scaricati al primo avvio; download fallito: errore e Riprova (da capo); niente registrazione prima che i modelli siano pronti.
- Segmentazione con finestre scorrevoli di più durate e scelta della sequenza migliore; dove nessuna parola è abbastanza somigliante si scrive "[?]".
- Punteggiatura con regole semplici: maiuscola a inizio frase e punto a fine frase, frasi separate dalle pause.
- Markdown: titolo con data, ora e durata, poi righe `[mm:ss] **Io:** …` / `**Altri:** …` in ordine cronologico; senza parlato, il file contiene "Nessun parlato rilevato".
- Chiusura della finestra impedita durante registrazione ed elaborazione; nessun recupero dopo un crash (l'audio parziale resta nella cartella).
- Cattura su Linux con processi esterni (`parecord`/`pw-record`); su macOS con un plugin Swift basato su ScreenCaptureKit.
- Finestra essenziale: Avvia/Ferma, stato, durata, avanzamento ed "Apri" per l'ultimo markdown.

Assunzioni non chieste esplicitamente:
- Chiudere la finestra durante il download dei modelli è permesso; il download ripartirà da capo al prossimo avvio.
- Su macOS il microfono si cattura nello stesso plugin nativo che usa ScreenCaptureKit.
- Cartella `~/CallToRecord`, nome file `AAAA-MM-GG_HH-MM-SS`, titolo del markdown `# Call del <data> alle <ora>` e testi esatti dei messaggi della finestra sono proposte da verificare.
- Una trascrizione fallita non scrive alcun markdown; il WAV si scrive su disco durante la registrazione.
- Durate delle finestre, soglie (confidenza, volume) e pausa di fine frase sono costanti da calibrare, raccolte in un solo punto.
