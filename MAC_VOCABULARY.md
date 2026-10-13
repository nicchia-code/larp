# Guida per l'agente su Mac: generare e pubblicare il vocabolario audio

Obiettivo: produrre `audio_vocabulary.tsv` e `audio_vocabulary.f32`, pubblicarli in una GitHub Release di questo repo e registrare nel codice URL e dimensioni esatte. Va fatto **su macOS** (un M1 basta): lo script usa `say` e `afconvert`. Non modificare `.trama/`: lo aggiorna chi lavora su Linux.

Il vocabolario deve essere generato con la stessa variante int8 di EmbeddingGemma 2 usata dall'app (`onnx-community/embeddinggemma-2-ONNX`). Se cambia la variante, va rigenerato.

## 1. Prerequisiti

```bash
gh auth status            # deve essere loggato come nicchia-code (o con accesso a nicchia-code/larp)
python3 --version
say -v '?' | grep -E "^(Luca|Alice|Alex|Samantha) "   # tutte e quattro devono comparire
```

Se una voce manca, installala da Impostazioni di Sistema > Accessibilità > Contenuto letto > Voce di sistema > Gestisci voci. Solo se non si può installare, cambia `VOICES` in `tool/build_audio_vocabulary.py` (maschile, femminile) per `it` e `en`, e annota la scelta nelle note della Release.

## 2. Ambiente Python e modello

```bash
python3 -m venv .venv && source .venv/bin/activate
pip install numpy onnxruntime transformers huggingface_hub
python3 tool/build_audio_vocabulary_test.py            # self-check dello script, deve passare

huggingface-cli download onnx-community/embeddinggemma-2-ONNX --local-dir ~/embgemma
ls ~/embgemma/onnx/audio_encoder_quantized.onnx ~/embgemma/onnx/model_quantized.onnx
```

La cartella deve contenere anche i file del tokenizer e del feature extractor (il comando sopra li scarica).

## 3. Liste di frequenza

Una parola per riga, la più frequente per prima. Il testo dopo la parola viene ignorato. Servono almeno 50.000 parole italiane e 20.000 inglesi (`DEFAULT_COUNTS` nello script).

```bash
B=https://raw.githubusercontent.com/hermitdave/FrequencyWords/master/content/2018
curl -fsSL $B/it/it_full.txt -o ~/it_full.txt
curl -fsSL $B/en/en_full.txt -o ~/en_full.txt
wc -l ~/it_full.txt ~/en_full.txt      # it >= 50000, en >= 20000
```

## 4. Generare il vocabolario

```bash
python3 tool/build_audio_vocabulary.py \
  --model-dir ~/embgemma --it-words ~/it_full.txt --en-words ~/en_full.txt --out ~/vocab
```

Sono circa 140.000 sintesi e embedding (ogni parola due volte): ci vorranno ore. Il progresso compare ogni 1000 parole. Lascialo girare senza interromperlo, per esempio dentro `caffeinate -i`.

Controllo sul risultato:

```bash
stat -f%z ~/vocab/audio_vocabulary.tsv ~/vocab/audio_vocabulary.f32
wc -l ~/vocab/audio_vocabulary.tsv
```

- `wc -l` deve dare 70.000 (50.000 it + 20.000 en).
- Il `.f32` deve pesare **esattamente 430.080.000 byte** (70.000 × 2 × 768 × 4). Se è diverso, la generazione è incompleta: non pubblicare, rigenera.

## 5. Pubblicare la Release

```bash
gh release create audio-vocabulary-v1 \
  ~/vocab/audio_vocabulary.tsv ~/vocab/audio_vocabulary.f32 \
  --repo nicchia-code/larp \
  --title "Audio vocabulary v1" \
  --notes "EmbeddingGemma 2 int8, 50000 it + 20000 en, voci: it Luca/Alice, en Alex/Samantha"
```

L'URL base della Release è:

```
https://github.com/nicchia-code/larp/releases/download/audio-vocabulary-v1
```

## 6. Registrare URL e dimensioni nel codice

In `lib/models/model_download.dart`:

1. Nelle due `ModelFile` del vocabolario sostituisci `null` con la dimensione in byte letta con `stat -f%z` (`audio_vocabulary.tsv` e `audio_vocabulary.f32`) e togli il commento `ponytail: vocabulary sizes stay null ...`.
2. Imposta l'URL base come valore predefinito di `audioVocabularyReleaseUrl`:
   ```dart
   const audioVocabularyReleaseUrl = String.fromEnvironment(
     'AUDIO_VOCABULARY_RELEASE_URL',
     defaultValue: 'https://github.com/nicchia-code/larp/releases/download/audio-vocabulary-v1',
   );
   ```

Poi:

```bash
flutter test
git add lib/models/model_download.dart
git commit -m "Record audio vocabulary release URL and sizes"
git push
```

## 7. Cosa riportare

Scrivi in chiaro: URL base, le due dimensioni in byte, il numero di righe del `.tsv`, le voci usate (se diverse da quelle sopra) e l'esito di `flutter test`.

## Attenzione: repo privato

`larp` è privato. Gli asset di una Release privata non si scaricano senza autenticazione: l'app, che scarica con una richiesta HTTP anonima, riceverebbe 404. Per far arrivare l'app a Pronto serve una di queste due cose, da decidere con Luca prima di dare per chiuso il lavoro:

- rendere pubblico il repo (o ospitare la Release in un repo pubblico a parte);
- aggiungere l'autenticazione al download del vocabolario nell'app.

Non scegliere da solo: segnalalo nel rapporto.
