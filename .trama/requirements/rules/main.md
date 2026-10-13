---
description: "Use when implementing how recorded audio becomes words, sentences and transcript lines, or the checks before recording and at startup."
---
# Transcription rules

## call/Ready
- Avvia verifica che esista un microfono predefinito e che l'audio del PC sia catturabile (su macOS, permesso concesso); altrimenti nomina la sorgente mancante.

## call/Transcribing
- Le tracce "Io" e "Altri" si trascrivono separatamente, ciascuna portata a mono 16 kHz con campioni float in [-1, 1].
- Segmentazione a finestre scorrevoli: su tutta la traccia si prendono finestre di più durate; ogni finestra si confronta, per similarità coseno, con tutti i vettori del vocabolario (entrambe le voci); poi si sceglie la sequenza di finestre non sovrapposte con la somiglianza complessiva migliore.
- La parola di una finestra è quella del vettore più simile.
- Una finestra con parlato ma con somiglianza massima sotto la soglia di confidenza diventa `[?]`.
- Le parti sotto la soglia di volume (silenzio) non producono parole.
- Una pausa più lunga della durata di fine frase chiude la frase; ogni frase inizia con la maiuscola e finisce con un punto; nessun'altra punteggiatura.
- L'istante di una frase è l'inizio della sua prima parola; le frasi di "Io" e "Altri" si intrecciano in ordine di istante.
- Durate e passo delle finestre, soglia di confidenza, soglia di volume e durata di fine frase sono costanti da calibrare, raccolte in un solo punto.
- Nessuna gestione dell'eco: si assume che l'utente usi le cuffie.

## models
- I modelli risultano presenti solo se tutti i file esistono con la dimensione attesa.
- Un download fallito cancella i file parziali; Riprova riparte da zero.
