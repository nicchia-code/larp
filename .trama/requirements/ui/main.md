---
description: "Use when building the app window, its buttons, messages and progress indicators."
---
# Window

## General
- Una sola finestra piccola; tutti i testi in italiano.
- Sempre visibile l'avviso: "Usa le cuffie: con le casse la voce degli altri finisce anche nella tua traccia."

## models/Downloading
- Testo "Download dei modelli…" con barra di avanzamento e MB scaricati sul totale.

## models/Download failed
- Messaggio d'errore e pulsante "Riprova".

## call/Waiting for models
- Pulsante "Avvia" visibile ma disabilitato.

## call/Ready
- Pulsante "Avvia".
- Se all'Avvia manca una sorgente: messaggio "Microfono non disponibile" o "Audio del PC non disponibile".

## call/Transcript available
- Nome del file markdown e pulsante "Apri".

## call/Transcription failed
- Messaggio d'errore e pulsante "Riprova"; "Avvia" resta disponibile.

## call/Recording
- Pulsante "Ferma", stato "Registrazione in corso" e durata `HH:MM:SS` che scorre.
- Tentativo di chiusura: dialogo "Ferma la registrazione prima di chiudere."

## call/Transcribing
- Stato "Trascrizione in corso" con barra di avanzamento in percentuale; "Avvia" disabilitato.
- Se la registrazione si è fermata per una sorgente persa: messaggio "Microfono perso: registrazione fermata" o "Audio del PC perso: registrazione fermata".
- Tentativo di chiusura: dialogo "Attendi la fine della trascrizione."
