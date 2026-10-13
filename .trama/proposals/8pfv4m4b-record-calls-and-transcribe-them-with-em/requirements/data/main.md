---
description: "Use when writing or reading the call audio files, the transcript markdown or the audio vocabulary."
---
# Files and vocabulary

## General
- Tutti i file delle call stanno nella cartella fissa `~/CallToRecord`, creata se manca.
- Ogni call produce due file con lo stesso nome base, la data e ora d'inizio nel formato `AAAA-MM-GG_HH-MM-SS`: `.wav` per l'audio e `.md` per la trascrizione.

## call/Recording
- Audio: un WAV stereo PCM 16 bit a 16 kHz; canale sinistro = microfono ("Io"), canale destro = audio del PC ("Altri").
- Il WAV si scrive su disco durante la registrazione, così ciò che è registrato resta anche se l'app muore.
- Il WAV si conserva dopo la trascrizione, riuscita o fallita.

## call/Transcribing
- Il markdown inizia con il titolo `# Call del <GG/MM/AAAA> alle <HH:MM>` e la riga `Durata: <HH:MM:SS>`.
- Seguono una riga per frase, `[mm:ss] **Io:** <testo>` oppure `[mm:ss] **Altri:** <testo>`, in ordine di istante d'inizio; l'orario parte dall'inizio della registrazione e diventa `[hh:mm:ss]` oltre la prima ora.
- Senza parlato riconosciuto il markdown contiene solo titolo, durata e la riga `Nessun parlato rilevato`.

## models
- Il vocabolario contiene circa 50.000 parole italiane e 20.000 inglesi, le più frequenti nel parlato, prese da liste di frequenza aperte tratte da sottotitoli.
- Per ogni parola: il testo, la lingua e due vettori a 768 dimensioni normalizzati, uno per voce (maschile e femminile).
